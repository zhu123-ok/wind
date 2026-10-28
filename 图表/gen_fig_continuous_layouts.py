"""绘制连续变量版两种算法的代表性折中布局。"""

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
from 工具.plot_utils import setup_style, save_fig, PALETTE, COLORS


ROOT = Path(__file__).resolve().parents[1]


def main():
    setup_style('colorblind')
    import matplotlib.pyplot as plt
    from matplotlib.patches import Rectangle

    data = json.loads((ROOT / '图表' / 'continuous_analysis_data.json').read_text(encoding='utf-8'))
    width, height = data['field']['width'], data['field']['height']
    fig, axes = plt.subplots(1, 2, figsize=(8.8, 7.3), sharex=True, sharey=True)
    for i, (ax, algorithm) in enumerate(zip(axes, ('CCGDE3', 'NSGA2'))):
        rep = data['representatives'][algorithm]
        layout = np.asarray(rep['layout'], dtype=float)
        ax.scatter(layout[:, 0], layout[:, 1], s=25, color=PALETTE[i],
                   marker='o' if i == 0 else '^', edgecolors='white', linewidths=0.4)
        for xmin, ymin, xmax, ymax in data['field']['obstacles']:
            ax.add_patch(Rectangle((xmin, ymin), xmax - xmin, ymax - ymin,
                                   facecolor=COLORS['gray'], edgecolor=COLORS['text'],
                                   alpha=0.30, linewidth=0.6))
        # 画出场区边界，并留一点外边距，防止边界上的风机标记被裁掉。
        ax.add_patch(Rectangle((0, 0), width, height, fill=False,
                               edgecolor=COLORS['text'], linewidth=0.8))
        ax.set_xlim(-0.02 * width, 1.02 * width)
        ax.set_ylim(-0.01 * height, 1.01 * height)
        ax.set_aspect('equal', adjustable='box')
        ax.set_xlabel('x 坐标（m）')
        ax.text(0.03, 0.97, f'({chr(97 + i)}) {algorithm}', transform=ax.transAxes,
                ha='left', va='top', fontsize=11)
        ax.text(0.03, 0.025,
                f"AEP={rep['AEP_GWh']:.1f} GWh/年\nLCOE={rep['LCOE']:.5f}\nCVaR95={rep['CVaR95_percent']:.2f}%",
                transform=ax.transAxes, ha='left', va='bottom', fontsize=9,
                bbox={'boxstyle': 'square,pad=0.25', 'facecolor': 'white',
                      'alpha': 0.86, 'edgecolor': COLORS['gray']})
        ax.grid(alpha=0.12, linestyle='--', color=COLORS['grid'])
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
    axes[0].set_ylabel('y 坐标（m）')
    fig.savefig(ROOT / '图表' / 'fig_continuous_layouts.png', dpi=350, bbox_inches='tight')
    save_fig(fig, str(ROOT / '图表' / 'fig_continuous_layouts.pdf'))


if __name__ == '__main__':
    main()
