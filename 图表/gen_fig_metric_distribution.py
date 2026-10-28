"""用配对点图展示 5 个随机种子的指标变化。"""

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

    data = json.loads((ROOT / "图表" / "analysis_data.json").read_text(encoding="utf-8"))
    fig, axes = plt.subplots(1, 3, figsize=(11.2, 4.2))
    specs = [("HV", "HV（越大越好）"), ("IGD", "IGD（越小越好）"),
             ("Spacing", "Spacing（越小越好）")]

    for panel, (ax, (metric, ylabel)) in enumerate(zip(axes, specs)):
        ccg = np.asarray([r[metric] for r in data["runs"] if r["algorithm"] == "CCGDE3"])
        nsga = np.asarray([r[metric] for r in data["runs"] if r["algorithm"] == "NSGA2"])
        for i in range(len(ccg)):
            ax.plot([0, 1], [ccg[i], nsga[i]], color=pu.COLORS["gray"], linewidth=1.0, alpha=0.7)
        ax.scatter(np.zeros(len(ccg)), ccg, s=42, color=pu.PALETTE[0], marker="o", zorder=3)
        ax.scatter(np.ones(len(nsga)), nsga, s=48, color=pu.PALETTE[1], marker="^", zorder=3)
        ax.scatter([0, 1], [ccg.mean(), nsga.mean()], s=110, facecolors="white",
                   edgecolors=[pu.PALETTE[0], pu.PALETTE[1]], linewidths=2.0, zorder=4)
        improvement = data["metrics"][metric]["NSGA2_relative_improvement_percent"]
        ax.text(0.5, 0.97, f"NSGA2 改善 {improvement:.1f}%", transform=ax.transAxes,
                ha="center", va="top", fontsize=9)
        ax.text(0.02, 0.04, f"({chr(97 + panel)})", transform=ax.transAxes, fontsize=10)
        ax.set_xticks([0, 1], ["CCGDE3", "NSGA2"])
        ax.set_ylabel(ylabel)
        ax.grid(axis="y", alpha=0.22, linewidth=0.7)
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)

    fig.tight_layout(w_pad=2.0)
    fig.savefig(ROOT / "图表" / "fig_metric_distribution.pdf", bbox_inches="tight")
    fig.savefig(ROOT / "图表" / "fig_metric_distribution.png", dpi=350, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    main()

