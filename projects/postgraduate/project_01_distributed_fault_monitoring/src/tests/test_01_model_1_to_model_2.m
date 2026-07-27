%% test_01_model_1_to_model_2.m  模型等价转换测试
%  填写 Model 1 数据，调用 model_1_to_model_2，输出 Model 2 数据，
%  再调用 assemble_global_model 组装全局矩阵，与 create_controlled_system 交叉验证。

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../../../utils/'));
addpath(genpath('../lib/'));
addpath(genpath('../scripts/'));

%% ============================================================
%  1. 填写 Model 1 数据（四容水箱）
% ============================================================

% --- 1a. 子系统数量 ---
n_s = 4;

% --- 1b. 状态空间矩阵（cell array）---
% 子系统 1 — 水箱1
A{1}     = 0.9842;
B{1}     = [0.0826, -0.0010];
C{1}     = 0.5;
D{1}     = [0, 0];
E{1}     = -0.0407;
F{1}     = 0;
C_s{1}   = 1;
D_s{1}   = [0, 0];

% 子系统 2 — 水箱2
A{2}     = 0.9890;
B{2}     = [-0.0005, 0.0625];
C{2}     = 0.5;
D{2}     = [0, 0];
E{2}     = -0.0326;
F{2}     = 0;
C_s{2}   = 1;
D_s{2}   = [0, 0];

% 子系统 3 — 水箱3（无测量输出）
A{3}     = 0.9590;
B{3}     = [0, 0.0469];
C{3}     = [];
D{3}     = [];
E{3}     = 0;
F{3}     = [];
C_s{3}   = 1;
D_s{3}   = [0, 0];

% 子系统 4 — 水箱4（无测量输出）
A{4}     = 0.9672;
B{4}     = [0.0307, 0];
C{4}     = [];
D{4}     = [];
E{4}     = 0;
F{4}     = [];
C_s{4}   = 1;
D_s{4}   = [0, 0];

% --- 1c. 网络拓扑 ---
N{1} = [3];            % 水箱1 接收 水箱3 的信息
N{2} = [4];            % 水箱2 接收 水箱4 的信息
N{3} = [];             % 水箱3 无邻居输入
N{4} = [];             % 水箱4 无邻居输入

M{1,3} = 1;            % 水箱3 → 1：原样传递
M{2,4} = 1;            % 水箱4 → 2：原样传递

%% ============================================================
%  2. 调用 Model_1_to_model_2
% ============================================================
fprintf('===== Model 1 → Model 2 转换 =====\n\n');

[A_bar, B_bar, C_bar, D_bar, E_bar, F_bar, C_s_bar, D_s_bar] = ...
    model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M, N);

%% ============================================================
%  3. 输出 Model 2 数据
% ============================================================

% --- 3a. A_bar（2D cell array, n_s × n_s）---
fprintf('A_bar（交叉状态矩阵，4×4 块）:\n');
fprintf('----------------------------------\n');
for i = 1:n_s
    for j = 1:n_s
        val = A_bar{i,j};
        if isempty(val)
            fprintf('  A_bar{%d,%d} = []\n', i, j);
        else
            fprintf('  A_bar{%d,%d} = %s\n', i, j, mat2str(val, 6));
        end
    end
end

% --- 3b. B_bar（1D cell array）---
fprintf('\nB_bar（有效输入矩阵，1×4）:\n');
fprintf('----------------------------------\n');
for i = 1:n_s
    if isempty(B_bar{i})
        fprintf('  B_bar{%d} = []\n', i);
    else
        fprintf('  B_bar{%d} = %s\n', i, mat2str(B_bar{i}, 6));
    end
end

% --- 3c. C_bar（2D cell array, n_s × n_s）---
fprintf('\nC_bar（交叉输出矩阵，4×4 块）:\n');
fprintf('----------------------------------\n');
for i = 1:n_s
    for j = 1:n_s
        val = C_bar{i,j};
        if isempty(val)
            fprintf('  C_bar{%d,%d} = []\n', i, j);
        else
            fprintf('  C_bar{%d,%d} = %s\n', i, j, mat2str(val, 6));
        end
    end
end

% --- 3d. D_bar（1D cell array）---
fprintf('\nD_bar（有效前馈矩阵，1×4）:\n');
fprintf('----------------------------------\n');
for i = 1:n_s
    if isempty(D_bar{i})
        fprintf('  D_bar{%d} = []\n', i);
    else
        fprintf('  D_bar{%d} = %s\n', i, mat2str(D_bar{i}, 6));
    end
end

% --- 3e. 耦合矩阵（原样传递）---
fprintf('\nE_bar, F_bar, C_s_bar, D_s_bar（原样传递）:\n');
fprintf('----------------------------------\n');
for i = 1:n_s
    fprintf('  E_bar{%d} = %s\n', i, mat2str(E_bar{i}, 6));
end

%% ============================================================
%  4. 调用 assemble_global_model 验证
% ============================================================
fprintf('\n===== 验证：assemble_global_model vs create_controlled_system =====\n\n');

n_x = [1, 1, 1, 1];
[A_g_test, B_g_test, C_g_test, D_g_test] = ...
    assemble_global_model(A_bar, B_bar, C_bar, D_bar, n_x);

[A_g_ref, B_g_ref, C_g_ref, D_g_ref] = create_controlled_system();

% A_g
err_A = max(abs(A_g_test(:) - A_g_ref(:)));
fprintf('全局 A 矩阵 (max |偏差| = %.2e):\n', err_A);
fprintf('  测试: \n'); disp(A_g_test);
fprintf('  参考: \n'); disp(A_g_ref);

% B_g
err_B = max(abs(B_g_test(:) - B_g_ref(:)));
fprintf('全局 B 矩阵 (max |偏差| = %.2e):\n', err_B);
fprintf('  测试: \n'); disp(B_g_test);
fprintf('  参考: \n'); disp(B_g_ref);

% C_g
err_C = max(abs(C_g_test(:) - C_g_ref(:)));
fprintf('全局 C 矩阵 (max |偏差| = %.2e):\n', err_C);
fprintf('  测试: \n'); disp(C_g_test);
fprintf('  参考: \n'); disp(C_g_ref);

% D_g
err_D = max(abs(D_g_test(:) - D_g_ref(:)));
fprintf('全局 D 矩阵 (max |偏差| = %.2e):\n', err_D);
fprintf('  测试: \n'); disp(D_g_test);
fprintf('  参考: \n'); disp(D_g_ref);

assert(err_A < 1e-12, 'A_g 与参考矩阵不一致！');
assert(err_B < 1e-12, 'B_g 与参考矩阵不一致！');
assert(err_C < 1e-12, 'C_g 与参考矩阵不一致！');
assert(err_D < 1e-12, 'D_g 与参考矩阵不一致！');
fprintf('\n✓ A_g, B_g, C_g, D_g 全部与参考矩阵一致（偏差 < 1e-12）\n');

%% ============================================================
%  5. 逐项断言
% ============================================================
fprintf('\n===== 逐项断言 =====\n\n');

% A_bar 对角（公式 7）
assert(abs(A_bar{1,1} - 0.9842) < 1e-10, 'A_bar{1,1} 错误');
assert(abs(A_bar{2,2} - 0.9890) < 1e-10, 'A_bar{2,2} 错误');
assert(abs(A_bar{3,3} - 0.9590) < 1e-10, 'A_bar{3,3} 错误');
assert(abs(A_bar{4,4} - 0.9672) < 1e-10, 'A_bar{4,4} 错误');
fprintf('✓ A_bar 对角块全部通过\n');

% A_bar 交叉耦合：公式 (7)
assert(abs(A_bar{1,3} - (-0.0407)) < 1e-10, 'A_bar{1,3} 错误');
assert(abs(A_bar{2,4} - (-0.0326)) < 1e-10, 'A_bar{2,4} 错误');
fprintf('✓ A_bar 交叉耦合块（公式 7）全部通过\n');

% A_bar 非邻居零块
assert(abs(A_bar{1,2}) < 1e-10, 'A_bar{1,2} 应为 0');
assert(abs(A_bar{1,4}) < 1e-10, 'A_bar{1,4} 应为 0');
assert(abs(A_bar{2,1}) < 1e-10, 'A_bar{2,1} 应为 0');
assert(abs(A_bar{2,3}) < 1e-10, 'A_bar{2,3} 应为 0');
fprintf('✓ A_bar 非邻居零块全部通过\n');

% B_bar：公式 (9) — D_s 均为 [0,0]，故 B_bar = B
assert(max(abs(B_bar{1} - [0.0826, -0.0010])) < 1e-10, 'B_bar{1} 错误');
assert(max(abs(B_bar{2} - [-0.0005, 0.0625])) < 1e-10, 'B_bar{2} 错误');
assert(max(abs(B_bar{3} - [0, 0.0469])) < 1e-10, 'B_bar{3} 错误');
assert(max(abs(B_bar{4} - [0.0307, 0])) < 1e-10, 'B_bar{4} 错误');
fprintf('✓ B_bar（公式 9）全部通过\n');

% C_bar 对角
assert(abs(C_bar{1,1} - 0.5) < 1e-10, 'C_bar{1,1} 错误');
assert(abs(C_bar{2,2} - 0.5) < 1e-10, 'C_bar{2,2} 错误');
fprintf('✓ C_bar 对角块全部通过\n');

% C_bar 交叉耦合：公式 (8) — F_1 = F_2 = 0
assert(abs(C_bar{1,3}) < 1e-10, 'C_bar{1,3} 应为 0（F_1=0）');
assert(abs(C_bar{2,4}) < 1e-10, 'C_bar{2,4} 应为 0（F_2=0）');
fprintf('✓ C_bar 交叉耦合块（公式 8）全部通过\n');

% 无传感器子系统
assert(isempty(C_bar{3,1}) && isempty(C_bar{4,1}), 'C_bar 无传感器行应为 []');
assert(isempty(D_bar{3}) && isempty(D_bar{4}), 'D_bar 无传感器子系统应为 []');
fprintf('✓ 无传感器子系统 C_bar/D_bar 全部为 []\n');

% E_bar, F_bar, C_s_bar, D_s_bar 原样传递
assert(isequal(E_bar{1}, E{1}), 'E_bar{1} 应与 E{1} 相等');
assert(isequal(F_bar{1}, F{1}), 'F_bar{1} 应与 F{1} 相等');
assert(isequal(C_s_bar{1}, C_s{1}), 'C_s_bar{1} 应与 C_s{1} 相等');
assert(isequal(D_s_bar{1}, D_s{1}), 'D_s_bar{1} 应与 D_s{1} 相等');
fprintf('✓ 耦合矩阵原样传递全部通过\n');

%% ============================================================
%  6. 汇总
% ============================================================
fprintf('\n===== 测试汇总 =====\n');
fprintf('  所有断言通过。Model 1 → Model 2 → Global 转换正确。\n');
