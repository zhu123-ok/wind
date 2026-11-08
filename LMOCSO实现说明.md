# LMOCSO 接入说明

已按 PlatEMO 的 LMOCSO 实现接入本项目统一入口，不需要安装完整 PlatEMO。

```matlab
addpath(fullfile(pwd,'WindFLO-master','MATLAB','project'));
% problem 为 windflo_prepare_continuous_problem 返回的连续布局问题。
options = struct('popSize',100,'maxFE',10000,'archiveSize',100,'verbose',true);
result = run_algorithm('LMOCSO',problem,options);
```

也支持名称 `lmo-cso`。算法专用覆盖字段为 `options.lmocso`。
`result` 沿用项目的 `archive`、`representative`、`best`、`history`、
`evaluations` 和 `cacheHits`，并返回含 `velocity` 的最终 `population`。

## 实现机制

1. 用 UniformPoint 的 NBI 方法生成固定三目标参考向量；初始化零速度粒子。
2. 计算移位密度适应度 SDE，随机两两竞争，数值较大的粒子胜出。
3. 败者按下式更新（r1、r2 为每对粒子各自的随机标量，各维共享）：

   `v_new = r1*v_loser + r2*(x_winner-x_loser)`

   `x_new = x_loser + v_new + r1*(v_new-v_loser)`

4. 拼接更新后的败者和胜者，两者都做多项式变异，变异概率 1/D、指数 20。
   胜者不是直接免评价复制，所有送入评价器的布局都计一次 FE。
5. 父子合并后先取非支配第一层，再按参考向量关联，以角度惩罚距离 APD
   为每个占用方向选一个粒子；惩罚系数为 `(FE/maxFE)^2`。

这套环境选择不同于 NSGA-II 的拥挤距离截断。种群会随占用方向数量变化，
不会强制补齐。只有一个粒子时按官方逻辑与自身竞争；奇数种群留一个未配对
粒子在父代池中。

## 数量与预算

- `popSize=100` 是请求值，三目标 NBI 实际生成 **91** 个参考向量并初始化
  91 个粒子，符合 PlatEMO 的行为；后续粒子数最多为 91。
- `result.parameters.requestedPopSize`、`initialPopSize` 和 `referenceVectors`
  保存这些信息，`history.populationSize` 记录每轮实际粒子数。
- `maxFE` 必须覆盖调整后的初始化数量。最后一批按剩余预算截断，保证精确
  达到 maxFE；缓存命中和修复失败仍计 FE。
- 速度、位置编码始终对应；几何修复后的物理布局用于共同目标评价，修复不
  反写编码或速度。目标仍为 `[-AEP, LCOE, CVaR95]`。

## 对比实验入口

```matlab
experiment = main_lmocso();
```

默认场景 00.xml、400 台风机、800 维、种子 1、每算法 10000 FE，
比较 NSGA2、CCGDE3、LMOCSO，输出到 `results_continuous_lmocso/`。
这是实际实验入口，默认规模可能耗时较长；本次接入未启动该长实验。

仅运行 LMOCSO 时：

```matlab
config = struct('algorithms',{{'LMOCSO'}},'nRuns',1);
config.options = struct('popSize',100,'maxFE',100000,'archiveSize',100);
experiment = main_lmocso(config);
```

原有 main_continuous 的默认算法列表不变。
本分支提供本地 MATLAB 运行入口；GPU 实验脚本与服务器配置单独维护。
Octave 和 MATLAB 的随机流实现不同，不宣称跨运行环境逐轨迹一致。

## 来源与验证

官方源文件、固定提交、校验值和适配差异保存在
`WindFLO-master/MATLAB/project/third_party/platemo_lmocso/`，该目录仅供对照，
不要递归加入 MATLAB 搜索路径，以免官方同名类覆盖项目适配器。

2026-11-08 本机 `test_lmocso` 短功能检查通过：

- 与固定版本官方 Operator 的子代位置和速度逐项对照一致（位置容差 1e-14）。
- 多种请求数量的 NBI 参考向量与官方 UniformPoint 完全一致。
- SDE 胜负方向、常数目标退化、APD 选择和无效目标过滤检查通过。
- 6、7、19、137 FE 的精确预算，以及相同随机种子可复现性通过。
- 场景 00.xml 的 20 台风机短测 37 FE，通过档案布局约束及目标重新计算检查。

这些是实现与接口检查，不支持算法优越性或统计收敛结论。正式比较需要多个
独立种子，并使用相同物理模型、修复器、评价预算与计算环境。
