"""生成两种算法代表性风机布局图。"""

import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from 工具 import plot_utils as pu  # noqa: E402


def main():
    pu.setup_style("colorblind")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Rectangle

    data = json.loads((ROOT / "图表" / "analysis_data.json").read_text(encoding="utf-8"))
    width, height = data["field"]["width"], data["field"]["height"]
    fig, axes = plt.subplots(1, 2, figsize=(8.8, 7.3), sharex=True, sharey=True)

    for i, (ax, algorithm) in enumerate(zip(axes, ("CCGDE3", "NSGA2"))):
        rep = data["representatives"][algorithm]
        layout = np.asarray(rep["layout"], dtype=float)
        ax.scatter(layout[:, 0], layout[:, 1], s=24, color=pu.PALETTE[i],
                   marker="o" if i == 0 else "^", edgecolors="white", linewidths=0.35)
        for obstacle in data["field"]["obstacles"]:
            xmin, ymin, xmax, ymax = obstacle
            ax.add_patch(Rectangle((xmin, ymin), xmax - xmin, ymax - ymin,
                                   facecolor=pu.COLORS["gray"], alpha=0.35))
        ax.set_xlim(0, width)
        ax.set_ylim(0, height)
        ax.set_aspect("equal", adjustable="box")
        ax.set_xlabel("x 坐标（m）")
        ax.text(0.03, 0.97, f"({chr(97 + i)}) {algorithm}", transform=ax.transAxes,
                ha="left", va="top", fontsize=11)
        ax.text(0.03, 0.025,
                f"AEP={rep['AEP_GWh']:.1f} GWh/年\nLCOE={rep['LCOE']:.4f}\nCVaR95={rep['CVaR95_percent']:.2f}%",
                transform=ax.transAxes, ha="left", va="bottom", fontsize=9,
                bbox={"facecolor": "white", "alpha": 0.82, "edgecolor": pu.COLORS["gray"]})
        ax.grid(alpha=0.15, linewidth=0.6)
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
    axes[0].set_ylabel("y 坐标（m）")
    fig.tight_layout(w_pad=1.3)
    fig.savefig(ROOT / "图表" / "fig_layouts.pdf", bbox_inches="tight")
    fig.savefig(ROOT / "图表" / "fig_layouts.png", dpi=350, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    main()

