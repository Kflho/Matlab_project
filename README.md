# Matlab

软件项目目录：纯代码/练习平铺，只有正式项目才拆 `src/`、`docs/`、`exports/`。

```text
Matlab/                       # 一个软件项目根，一个 git 仓库
  projects/
    ml_2_1/                  # 简单练习：一个文件夹，平铺
      case_2_1.m ...
  matlab-project-utils/      # 共享代码库，平铺
    calculations/
    initialization/
    plots/
    simulink/
    visualizations/
```

- 简单练习不拆 `requirements/`、`src/`、`exports/`，一个文件夹即可；
- 共享代码库放 `matlab-project-utils/` 根目录，平铺，不要再放回练习项目的 `utils/`；
- 练习项目和共享库同属这个仓库，不再嵌套独立 `.git`；
- `.old/` 是历史备份，不参与当前项目，其中保留了旧练习仓库的 bundle；
- MATLAB 里使用时把用到的 `src` 加入 path，例如 `addpath('matlab-project-utils/plots')`。
