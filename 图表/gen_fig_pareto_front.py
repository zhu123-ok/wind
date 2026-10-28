"""生成三目标经验 Pareto 前沿图。"""

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
    fig = plt.figure(figsize=(8.6, 6.5))
    ax = fig.add_subplot(111, projection="3d")
    markers = {"CCGDE3": "o", "NSGA2": "^"}

    for i, algorithm in enumerate(("CCGDE3", "NSGA2")):
        all_values = np.asarray([p["objective"] for p in data["allPoints"] if p["algorithm"] == algorithm])
        ax.scatter(-all_values[:, 0] / 1e6, all_values[:, 1], 100 * all_values[:, 2],
                   s=13, alpha=0.12, color=pu.PALETTE[i], marker=markers[algorithm])
        front = np.asarray([p["objective"] for p in data["referenceFront"] if p["algorithm"] == algorithm])
        if len(front):
            ax.scatter(-front[:, 0] / 1e6, front[:, 1], 100 * front[:, 2],
                       s=42, alpha=0.9, color=pu.PALETTE[i], marker=markers[algorithm],
                       edgecolors="white", linewidths=0.45,
                       label=f"{algorithm}（经验前沿）")

    ax.set_xlabel("AEP（GWh/年）", labelpad=8)
    ax.set_ylabel("LCOE（成本单位/kWh）", labelpad=9)
    ax.set_zlabel("CVaR95（%）", labelpad=7)
    ax.view_init(elev=24, azim=-54)
    ax.grid(True, alpha=0.22)
    ax.legend(loc="upper left", bbox_to_anchor=(0.01, 0.98))
    # 3D 坐标轴也保持和其他图一致的简洁边框。
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.savefig(ROOT / "图表" / "fig_pareto_front.pdf", bbox_inches="tight")
    fig.savefig(ROOT / "图表" / "fig_pareto_front.png", dpi=350, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    main()

