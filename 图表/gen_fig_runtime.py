"""展示运行时间和最终外部档案规模。"""

import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from 工具 import plot_utils as pu  # noqa: E402


def paired_panel(ax, ccg, nsga, ylabel, letter):
    for i in range(len(ccg)):
        ax.plot([0, 1], [ccg[i], nsga[i]], color=pu.COLORS["gray"], linewidth=1.0, alpha=0.7)
    ax.scatter(np.zeros(len(ccg)), ccg, s=42, color=pu.PALETTE[0], marker="o", zorder=3)
    ax.scatter(np.ones(len(nsga)), nsga, s=48, color=pu.PALETTE[1], marker="^", zorder=3)
    ax.scatter([0, 1], [np.mean(ccg), np.mean(nsga)], s=110, facecolors="white",
               edgecolors=[pu.PALETTE[0], pu.PALETTE[1]], linewidths=2.0, zorder=4)
    ax.set_xticks([0, 1], ["CCGDE3", "NSGA2"])
    ax.set_ylabel(ylabel)
    ax.text(0.02, 0.04, f"({letter})", transform=ax.transAxes, fontsize=10)
    ax.grid(axis="y", alpha=0.22, linewidth=0.7)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)


def main():
    pu.setup_style("colorblind")
    import matplotlib.pyplot as plt

    data = json.loads((ROOT / "图表" / "analysis_data.json").read_text(encoding="utf-8"))
    fig, axes = plt.subplots(1, 2, figsize=(8.4, 4.2))
    ccg_runs = [r for r in data["runs"] if r["algorithm"] == "CCGDE3"]
    nsga_runs = [r for r in data["runs"] if r["algorithm"] == "NSGA2"]
    paired_panel(axes[0], np.asarray([r["timeSeconds"] for r in ccg_runs]),
                 np.asarray([r["timeSeconds"] for r in nsga_runs]), "运行时间（s）", "a")
    paired_panel(axes[1], np.asarray([r["archiveSize"] for r in ccg_runs]),
                 np.asarray([r["archiveSize"] for r in nsga_runs]), "档案解数", "b")
    axes[0].text(0.5, 0.97,
                 f"NSGA2 节省 {data['metrics']['timeSeconds']['NSGA2_relative_improvement_percent']:.1f}%",
                 transform=axes[0].transAxes, ha="center", va="top", fontsize=9)
    fig.tight_layout(w_pad=2.2)
    fig.savefig(ROOT / "图表" / "fig_runtime.pdf", bbox_inches="tight")
    fig.savefig(ROOT / "图表" / "fig_runtime.png", dpi=350, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    main()

