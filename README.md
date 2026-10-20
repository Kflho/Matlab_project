# Matlab_project

MATLAB 控制系统实验代码：共享函数库 `matlab-project-utils/` + 练习项目 `projects/`。整个目录就是一个软件项目根，一个 git 仓库，不嵌套别的仓库。

## 快速开始

在 MATLAB 里把共享库加进路径，然后直接调函数：

```matlab
addpath(genpath('matlab-project-utils'));
[A,B,C,D] = create_controlled_system();
K = calculate_lqr(A,B);
```

只用一个模块时按需加，不必整库加载：

```matlab
addpath('matlab-project-utils/plots');
```

## 安装与依赖

- MATLAB + **Control System Toolbox**（`dlqr`、`ss`）；
- Simulink：只有 `matlab-project-utils/simulink/controlled_system.slx` 需要；
- 没有 `requirements.txt` 这类清单，`.m` 文件直接跑。

## 目录结构

```text
Matlab_project/
  README.md
  projects/
    ml_2_1/                        # 简单练习：一个文件夹平铺，12 个 .m
  matlab-project-utils/            # 共享库（库根就是代码根）
    README.md                      # 模块清单与调用示例
    calculations/
    initialization/
    plots/
    simulink/
    visualizations/
```

## 用法

- 画信号：`plot_signals_v5(y, 'y', '阶跃响应', 1, {'t / s','y'}, {'y_1','y_2'})`，再 `run_visualization(gcf)` 套论文格式；
- 加阈值线：`add_threshold(1.05, '1.05 倍稳态值', gca)`；
- 导出图：`export_fig_paper(gcf, 'step_response', 5.5)`，输出 600 dpi PNG；
- 噪声与离散化：`create_noise_v2(n, sigma_diag)`、`discretization_controlled_system()`。

## 输出

`export_fig_paper` 在当前目录写 `<fileName>.png`（600 dpi），不覆盖 `.m`；其余函数只返回数据或改当前图窗。

## 验证

```matlab
addpath(genpath('matlab-project-utils'));
which calculate_energy                       % 应指向 ...\src\calculations\calculate_energy.m
[A,B,C,D] = create_controlled_system();      % 依赖齐全时无报错
K = calculate_lqr(A,B);
```

## 已知限制

- 没有自动化测试，改动靠手工跑一遍；
- 权重和版式写死在源码里（`calculate_lqr` 的 Q/R、`run_visualization` 的字号线宽），换参数要改函数；
- `.old/` 是历史备份（约 20 MB，不进 git），不要从里面引代码；
- 练习项目和共享库同仓库，共享库不做独立版本号。

## 文档

- 共享库模块清单与示例：[`matlab-project-utils/README.md`](matlab-project-utils/README.md)
