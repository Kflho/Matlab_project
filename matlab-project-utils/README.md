# matlab-project-utils

控制系统实验用的共享 MATLAB 函数库。代码在 `src/`，按用途分目录；这份文件是模块清单和最小调用示例。

## 快速开始

```matlab
addpath(genpath('matlab-project-utils/src'));
```

## 模块

| 目录 | 入口函数 | 作用 |
|---|---|---|
| `src/calculations` | `calculate_energy(ts)`、`calculate_signal_stats(ts, t0, t1)` | 时间序列的模长平方；指定时间窗内的累积能量与均值 |
| `src/initialization/create_controlled_system` | `create_controlled_system()`、`calculate_lqr(A,B)`、`discretization_controlled_system()` | 被控对象状态空间、LQR 增益、连续系统离散化 |
| `src/initialization/create_noise` | `create_noise_v2(n, sigma_diag)` | 高斯白噪声的协方差矩阵与 timeseries 序列 |
| `src/plots` | `plot_signals_v5(...)`、`add_threshold(...)`、`export_fig_paper(...)` | 画曲线、加阈值线、按论文尺寸导出 |
| `src/visualizations` | `run_visualization(fig)` | 统一字体、线宽、坐标轴与图例格式 |
| `src/simulink` | `controlled_system.slx` | 被控对象仿真模型 |

## 最小示例

```matlab
[A,B,C,D] = create_controlled_system();
K = calculate_lqr(A,B);

fig = figure;
plot_signals_v5(y, 'y', '阶跃响应', 1, {'t / s','y'}, {'y_1','y_2'});
add_threshold(1.05, '1.05 倍稳态值', gca);
run_visualization(fig);
export_fig_paper(fig, 'step_response', 5.5);
```

`export_fig_paper` 在当前目录写 `step_response.png`（600 dpi），不覆盖源文件。

## 兼容性

- 需要 **Control System Toolbox**（`dlqr`、`ss`）；
- `src/simulink` 里的模型需要 Simulink；
- 没有用 `arguments` 参数块，老版本 MATLAB 也能跑；实际可用的最低版本以本机实测为准。

## 约定

- 画图和排版分开：`plot_signals_v5`、`add_threshold` 只管数据与图例，字体线宽一律交给 `run_visualization`；
- 新函数按用途放进对应 `src/` 子目录，不要放回练习项目；
- 改公共函数前先查调用点，例如 `grep -rn "calculate_energy" .`。
