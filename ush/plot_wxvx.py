#!/usr/bin/env python3

import argparse
import logging
from pathlib import Path
from typing import cast

import cartopy
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import matplotlib as mpl
import matplotlib.pyplot as plt

import numpy as np
import xarray as xr
import yaml

if False:  # For type checking only
    from cartopy.mpl.geoaxes import GeoAxes  # type: ignore[import-untyped]


def plot_basic(
    ncpath: Path,
    pngpath: Path,
    stat: str,
) -> None:
    """
    Generate a basic plot of a statistic from a NetCDF file.
    """
    logging.info("Plotting %s -> %s", ncpath, pngpath)

    pngpath.parent.mkdir(parents=True, exist_ok=True)

    with xr.open_dataset(ncpath) as ds:
        var_stat = cast("xr.DataArray", ds[stat])
        ax = var_stat.plot()  # type: ignore[call-arg]
        fig = ax[0].figure
        fig.savefig(pngpath)
        plt.close(fig)

    logging.info("Wrote plot: %s", pngpath)


def plot_spatial_stat(
    ncpath: Path,
    pngpath: Path,
    cfg: dict,
) -> None:
    """
    Generate a spatial-stat PNG plot from a grid2grid verification NetCDF file.
    """
    logging.info("Plotting spatial statistics: %s -> %s", ncpath, pngpath)

    with xr.open_dataset(ncpath) as ds:
        var = _choose_diff_var(ds)
        da = _mask_fill(_pick_2d(ds[var]))
        vmin, vmax = _finite_min_max(da)
        units = str(ds[var].attrs.get("units", "")).strip()

        lat2d = np.asarray(ds["lat"].values)
        lon2d = _to_lon180(np.asarray(ds["lon"].values))

        extents = [
            float(np.nanmin(lon2d)),
            float(np.nanmax(lon2d)),
            float(np.nanmin(lat2d)),
            float(np.nanmax(lat2d)),
        ]

        fig = plt.figure(
            figsize=(cfg["figsize"]["w"], cfg["figsize"]["h"])
        )
        fig.suptitle(
            ncpath.name,
            fontsize=cfg["file_fontsize"],
            y=cfg["suptitle_y"],
        )

        ax = cast("GeoAxes", plt.axes(projection=ccrs.PlateCarree()))
        ax.set_extent(extents, crs=ccrs.PlateCarree())

        back_res = "50m"
        
        coastline = cfeature.NaturalEarthFeature(
            category="physical",
            name="coastline",
            scale=back_res,
            edgecolor="black",
            facecolor="none",
            linewidth=0.8,
        )
        
        borders = cfeature.NaturalEarthFeature(
            category="cultural",
            name="admin_0_countries",
            scale=back_res,
            edgecolor="black",
            facecolor="none",
            linewidth=0.6,
        )
        
        ax.add_feature(coastline)
        ax.add_feature(borders)

        mesh = ax.pcolormesh(
            lon2d,
            lat2d,
            np.asarray(da.values),
            transform=ccrs.PlateCarree(),
            vmin=vmin,
            vmax=vmax,
            cmap=cfg["cmap"],
        )

        if cfg["add_states"]:
            ax.add_feature(cfeature.STATES, linewidth=0.4)

        if cfg["gridlines"]:
            gl = ax.gridlines(draw_labels=True, linewidth=0.3, alpha=0.6)
            gl.right_labels = False
            gl.top_labels = False

        ax.set_title(
            _build_main_title(ds, var),
            fontsize=cfg["title_fontsize"],
        )

        cb = fig.colorbar(
            mesh,
            ax=ax,
            orientation="horizontal",
            pad=0.12,
            fraction=0.06,
        )
        cb.set_label(units or var)

        plt.tight_layout(rect=(0, 0, 1, 0.94))
        pngpath.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(pngpath, dpi=150)
        plt.close(fig)

    logging.info("Wrote spatial-stat plot: %s", pngpath)


def plot_basic_all(
    ncdir: Path,
    outdir: Path,
    variables: list[str],
    stats: list[str],
) -> None:
    """
    Generate basic plots for all requested variables and statistics.

    Assumes each variable has a corresponding <variable>.nc file.
    """
    for var in variables:
        ncpath = ncdir / f"{var}.nc"

        if not ncpath.is_file():
            logging.warning("NetCDF file not found: %s", ncpath)
            continue

        for stat in stats:
            pngpath = outdir / f"{var}_{stat}.png"

            try:
                plot_basic(ncpath, pngpath, stat)
            except KeyError:
                logging.warning(
                    "Statistic '%s' not found in %s; skipping.",
                    stat,
                    ncpath,
                )


def plot_spatial_stat_all(
    stats_root: Path,
    outdir: Path,
    cfg: dict,
) -> None:
    """
    Generate spatial-stat plots for all grid2grid verification NetCDF files.
    """
    ncpaths = sorted(stats_root.rglob("grid_stat_*_pairs.nc"))

    if not ncpaths:
        logging.warning("No grid_stat_*_pairs.nc files found in %s", stats_root)
        return

    for ncpath in ncpaths:
        pngpath = outdir / f"{ncpath.stem}_spatial.png"
        plot_spatial_stat(ncpath, pngpath, cfg)


def _build_main_title(ds: xr.Dataset, var: str) -> str:
    get = lambda x: str(ds[var].attrs.get(x, "")).strip()

    long_name = get("long_name") or var
    init_time = get("init_time")
    valid_time = get("valid_time")
    diff_desc = str(ds.attrs.get("Difference", "")).strip()

    lines: list[str] = [long_name]

    if init_time or valid_time:
        lines.append(f"init={init_time} valid={valid_time}")

    if diff_desc:
        lines.append(f"Difference: {diff_desc}")

    return "\n".join(lines)


def _choose_diff_var(ds: xr.Dataset) -> str:
    for k in ds.data_vars:
        v = cast("str", k)
        if v.startswith("DIFF_"):
            return v

    raise AttributeError(
        "No DIFF_ variable in %s" % ds.encoding.get("source", "unknown file")
    )


def _finite_min_max(da: xr.DataArray) -> tuple[float, float]:
    a = np.asarray(da.values).astype("float64", copy=False)
    a = a[np.isfinite(a)]

    if a.size == 0:
        raise ValueError("All values are NaN/inf after masking fill values.")

    return float(a.min()), float(a.max())


def _mask_fill(da: xr.DataArray) -> xr.DataArray:
    fill = da.attrs.get("_FillValue")
    miss = da.attrs.get("missing_value")

    if fill is None:
        fill = da.encoding.get("_FillValue")

    out = da

    if fill is not None:
        out = out.where(out != fill)

    if miss is not None:
        out = out.where(out != miss)

    return out


def _pick_2d(da: xr.DataArray) -> xr.DataArray:
    while da.ndim > 2:
        da = da.isel({da.dims[0]: 0})

    return da


def _to_lon180(lon2d: np.ndarray) -> np.ndarray:
    lon = np.asarray(lon2d, dtype="float64")
    return ((lon + 180.0) % 360.0) - 180.0


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate basic and spatial-stat plots from wxvx NetCDF files."
    )
    parser.add_argument(
        "config",
        type=Path,
        help="YAML configuration file.",
    )
    args = parser.parse_args()

    with args.config.open("r") as f:
        config = yaml.safe_load(f)

    # Configure Cartopy to use the local Natural Earth data.
    cartopy_ne_path = Path(config["cartopy_ne_path"])
    cartopy.config["data_dir"] = str(cartopy_ne_path)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s: %(message)s",
    )

    logging.info("Cartopy Natural Earth directory: %s", cartopy_ne_path)

    # Input and output directories.
    ncdir = Path(config["ncdir"])
    spatial_stats_root = Path(config["spatial_stats_root"])
    basic_outdir = Path(config["basic_outdir"])
    spatial_outdir = Path(config["spatial_outdir"])

    # Plot configuration.
    variables = [
        "2m_temperature",
        "10m_zonal_wind",
        "10m_meridional_wind",
    ]

    stats = ["ME", "RMSE"]

    spatial_cfg = {
        "figsize": {"w": 12, "h": 7},
        "file_fontsize": 10,
        "suptitle_y": 0.98,
        "title_fontsize": 11,
        "cmap": "RdBu_r",
        "add_states": False,
        "gridlines": True,
    }

    plot_basic_all(
        ncdir=ncdir,
        outdir=basic_outdir,
        variables=variables,
        stats=stats,
    )

    plot_spatial_stat_all(
        stats_root=spatial_stats_root,
        outdir=spatial_outdir,
        cfg=spatial_cfg,
    )


if __name__ == "__main__":
    main()
