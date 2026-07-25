%% Test_02_assemble_global_model.m  全局组装测试
%  验证 Assemble_global_model 按公式 (11)-(14) 正确拼接全局矩阵。
%  与 Create_controlled_system.m 的全局矩阵逐元素比对。
%  额外测试：手动构造简单系统，验证分块拼接逻辑。

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../../Common/'));
addpath(genpath('../Function/'));
addpath(genpath('../Script/'));

%% ============================================================
%  1. 四容水箱：完整链路 Model 1 → Model 2 → Global
% ============================================================
Create_model_1;

[A_bar, B_bar, C_bar, D_bar] = ...
    Model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M, N);

n_x = [1, 1, 1, 1];
[A_g, B_g, C_g, D_g] = Assemble_global_model(A_bar, B_bar, C_bar, D_bar, n_x);

[A_ref, B_ref, C_ref, D_ref] = Create_controlled_system();

fprintf('===== 四容水箱全局矩阵比对 =====\n\n');

err_A = max(abs(A_g(:) - A_ref(:)));
err_B = max(abs(B_g(:) - B_ref(:)));
err_C = max(abs(C_g(:) - C_ref(:)));
err_D = max(abs(D_g(:) - D_ref(:)));

fprintf('  max|A_g - A_ref| = %.2e\n', err_A);
fprintf('  max|B_g - B_ref| = %.2e\n', err_B);
fprintf('  max|C_g - C_ref| = %.2e\n', err_C);
fprintf('  max|D_g - D_ref| = %.2e\n', err_D);

assert(err_A < 1e-12, 'A_g 不匹配');
assert(err_B < 1e-12, 'B_g 不匹配');
assert(err_C < 1e-12, 'C_g 不匹配');
assert(err_D < 1e-12, 'D_g 不匹配');
fprintf('✓ 全部通过（偏差 < 1e-12）\n');

%% ============================================================
%  2. 维度验证
% ============================================================
fprintf('\n===== 维度验证 =====\n\n');

assert(isequal(size(A_g), [4, 4]), 'A_g 应为 4×4');
assert(isequal(size(B_g), [4, 2]), 'B_g 应为 4×2');
assert(isequal(size(C_g), [2, 4]), 'C_g 应为 2×4（跳过子系统3,4）');
assert(isequal(size(D_g), [2, 2]), 'D_g 应为 2×2');
fprintf('✓ 维度全部正确\n');

%% ============================================================
%  3. 分块位置数值验证
% ============================================================
fprintf('\n===== 分块位置数值验证 =====\n\n');

% A_g(1,3) = A_bar{1,3} = -0.0407
assert(abs(A_g(1,3) - (-0.0407)) < 1e-10, 'A_g(1,3) 错误');
% A_g(2,4) = A_bar{2,4} = -0.0326
assert(abs(A_g(2,4) - (-0.0326)) < 1e-10, 'A_g(2,4) 错误');
% B_g(1,:) = B_bar{1} = [0.0826, -0.0010]
assert(max(abs(B_g(1,:) - [0.0826, -0.0010])) < 1e-10, 'B_g(1,:) 错误');
% C_g(1,1) = C_bar{1,1} = 0.5
assert(abs(C_g(1,1) - 0.5) < 1e-10, 'C_g(1,1) 错误');

fprintf('✓ 所有分块位置数值正确\n');

%% ============================================================
%  4. 简单系统测试（2 子系统，全有输出）
% ============================================================
fprintf('\n===== 简单系统测试（2 子系统，全有输出）=====\n\n');

% 子系统 1
A_s{1} = 0.5;  B_s{1} = 1;    C_s{1} = 2;    D_s{1} = 0;
E_s{1} = 0.1;  F_s{1} = 0.2;
Cs_s{1} = 3;   Ds_s{1} = 0.4;

% 子系统 2（无耦合输出）
A_s{2} = 0.6;  B_s{2} = 1.5;  C_s{2} = 2.5;  D_s{2} = 0;
E_s{2} = 0;    F_s{2} = 0;
Cs_s{2} = 4;   Ds_s{2} = 0;

% 拓扑：子系统1 接收 子系统2 的信息
N_s{1} = [2];  N_s{2} = [];
M_s{1,2} = 0.3;

% 预期（公式 7-10）：
%   A_bar{1,1}=0.5,  A_bar{1,2}=0.1×0.3×4=0.12
%   A_bar{2,1}=0,    A_bar{2,2}=0.6
%   B_bar{1}=1+0.1×0.3×0=1,  B_bar{2}=1.5
%   C_bar{1,1}=2,    C_bar{1,2}=0.2×0.3×4=0.24
%   C_bar{2,1}=0,    C_bar{2,2}=2.5
%   D_bar{1}=0+0.2×0.3×0=0,  D_bar{2}=0

[A_b, B_b, C_b, D_b] = Model_1_to_model_2(A_s, B_s, C_s, D_s, ...
    E_s, F_s, Cs_s, Ds_s, M_s, N_s);

[A_s_g, B_s_g, C_s_g, D_s_g] = Assemble_global_model(A_b, B_b, C_b, D_b, [1, 1]);

A_s_expected = [0.5, 0.12; 0, 0.6];
B_s_expected = [1; 1.5];
C_s_expected = [2, 0.24; 0, 2.5];
D_s_expected = [0; 0];

assert(max(abs(A_s_g(:) - A_s_expected(:))) < 1e-12, '简单系统 A_g 不匹配');
assert(max(abs(B_s_g(:) - B_s_expected(:))) < 1e-12, '简单系统 B_g 不匹配');
assert(max(abs(C_s_g(:) - C_s_expected(:))) < 1e-12, '简单系统 C_g 不匹配');
assert(max(abs(D_s_g(:) - D_s_expected(:))) < 1e-12, '简单系统 D_g 不匹配');

fprintf('  A_g = \n'); disp(A_s_g);
fprintf('  B_g = \n'); disp(B_s_g);
fprintf('  C_g = \n'); disp(C_s_g);
fprintf('  D_g = \n'); disp(D_s_g);
fprintf('✓ 简单系统组装全部通过\n');

%% ============================================================
%  5. 汇总
% ============================================================
fprintf('\n===== 测试汇总 =====\n');
fprintf('  所有断言通过。Assemble_global_model 正确实现公式 (11)-(14)。\n');
