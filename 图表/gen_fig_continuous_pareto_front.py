"""绘制连续变量版三目标 Pareto 前沿。"""

import os, sys, shutil
os.makedirs('工具', exist_ok=True)
for src in ['plot_utils.py']:
    for search in ['skills/shared-scripts', '../skills/shared-scripts']:
        p = os.path.join(search, src)
        if os.path.isfile(p):
            shutil.copy2(p, f'工具/{src}')
            break
sys.path.insert(0, '.')

import json
from pathlib import Path
import numpy as np
from 工具.plot_utils import setup_style, save_fig, PALETTE


ROOT = Path(__file__).resolve().parents[1]


def main():
    setup_style('colorblind')
    import matplotlib.pyplot as plt

    data = json.loads((ROOT / '图表' / 'continuous_analysis_data.json').read_text(encoding='utf-8'))
    fig = plt.figure(figsize=(8.4, 6.4))
    ax = fig.add_subplot(111, projection='3d')
    markers = {'CCGDE3': 'o', 'NSGA2': '^'}
    for i, algorithm in enumerate(('CCGDE3', 'NSGA2')):
        values = np.asarray([p['objective'] for p in data['allPoints'] if p['algorithm'] == algorithm])
        front = np.asarray([p['objective'] for p in data['referenceFront'] if p['algorithm'] == algorithm])
        ax.scatter(-values[:, 0] / 1e6, values[:, 1], 100 * values[:, 2],
                   s=12, alpha=0.10, color=PALETTE[i], marker=markers[algorithm])
        if len(front):
            ax.scatter(-front[:, 0] / 1e6, front[:, 1], 100 * front[:, 2],
                       s=40, alpha=0.92, color=PALETTE[i], marker=markers[algorithm],
                       edgecolors='white', linewidths=0.5,
                       label=f"{algorithm}（经验前沿 {len(front)} 个）")
    ax.set_xlabel('AEP（GWh/年）', labelpad=8)
    ax.set_ylabel('LCOE（成本单位/kWh）', labelpad=9)
    ax.set_zlabel('CVaR95（%）', labelpad=3)
    ax.view_init(elev=24, azim=-54)
    ax.grid(True, alpha=0.16)
    ax.legend(loc='upper left', bbox_to_anchor=(0.01, 0.98))
    # 3D 坐标轴的 z 标签较靠右，保留额外边距防止 PDF 裁切。
    fig.subplots_adjust(left=0.03, right=0.90, bottom=0.06, top=0.96)
    fig.savefig(ROOT / '图表' / 'fig_continuous_pareto_front.png',
                dpi=350, bbox_inches='tight', pad_inches=0.25)
    fig.savefig(ROOT / '图表' / 'fig_continuous_pareto_front.pdf',
                bbox_inches='tight', pad_inches=0.25)
    plt.close(fig)


if __name__ == '__main__':
    main()
