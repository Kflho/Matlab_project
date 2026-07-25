%% Test_03_solve_luenberger_lmi.m  Luenberger LMI 求解测试
%  通过完整链路 Model 1 → Model 2 → Global 获取 A_g/C_g，
%  调用 Solve_luenberger_lmi 求解 A_z 和 L，验证：
%    1. A_z = A_g - L·C_g（Luenberger 条件）
%    2. A_z 的 Schur 稳定性（所有 |λ| < 1）
%    3. L 的维度正确性
%    4. 噪声协方差正定性传递

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../../Common/'));
addpath(genpath('../Function/'));
addpath(genpath('../Script/'));

%% ============================================================
%  1. 构建全局矩阵（完整链路）
% ============================================================
fprintf('===== 1. 构建全局矩阵 =====\n\n');

Create_model_1;

[A_bar, B_bar, C_bar, D_bar] = ...
    Model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M, N);

n_x = [1, 1, 1, 1];
[A_g, B_g, C_g, D_g] = Assemble_global_model(A_bar, B_bar, C_bar, D_bar, n_x);

fprintf('A_g = %d×%d, C_g = %d×%d\n', size(A_g, 1), size(A_g, 2), ...
    size(C_g, 1), size(C_g, 2));
fprintf('A_g =\n'); disp(A_g);
fprintf('C_g =\n'); disp(C_g);

%% ============================================================
%  2. 调用 Solve_luenberger_lmi
% ============================================================
fprintf('\n===== 2. 调用 Solve_luenberger_lmi =====\n\n');

[A_z, L] = Solve_luenberger_lmi(A_g, C_g, Sigma_w, Sigma_v);

%% ============================================================
%  3. 验证 Luenberger 条件：A_z = A_g - L·C_g
% ============================================================
fprintf('\n===== 3. 验证 Luenberger 条件 =====\n\n');

A_z_expected = A_g - L * C_g;
err_Az = max(abs(A_z(:) - A_z_expected(:)));
fprintf('max|A_z - (A_g - L·C_g)| = %.2e\n', err_Az);
assert(err_Az < 1e-10, 'Luenberger 条件不满足：A_z ≠ A_g - L·C_g');
fprintf('✓ Luenberger 条件满足（A_z = A_g - L·C_g）\n');

%% ============================================================
%  4. 验证 Schur 稳定性
% ============================================================
fprintf('\n===== 4. 验证 Schur 稳定性 =====\n\n');

eig_Az = eig(A_z);
abs_eig_Az = abs(eig_Az);

fprintf('A_z 特征值：\n');
for i = 1:length(eig_Az)
    fprintf('  λ_%d = %10.6f + %10.6fi,  |λ| = %.6f', ...
        i, real(eig_Az(i)), imag(eig_Az(i)), abs_eig_Az(i));
    if abs_eig_Az(i) < 1
        fprintf('  ✓\n');
    else
        fprintf('  ✗ (不稳定!)\n');
    end
end

assert(all(abs_eig_Az < 1), 'A_z 不是 Schur 稳定的！');
fprintf('✓ A_z 是 Schur 稳定的（所有 |λ| < 1）\n');

%% ============================================================
%  5. 验证维度正确性
% ============================================================
fprintf('\n===== 5. 验证维度 =====\n\n');

assert(isequal(size(A_z), [4, 4]), 'A_z 应为 4×4');
assert(isequal(size(L), [4, 2]), 'L 应为 4×2（4 状态 × 2 输出）');
fprintf('✓ A_z 维度 4×4, L 维度 4×2\n');

%% ============================================================
%  6. 验证理论性质
% ============================================================
fprintf('\n===== 6. 验证理论性质 =====\n\n');

% 6a. 构建全噪声协方差并验证正定性传递
if iscell(Sigma_w)
    Sigma_w_full = blkdiag(Sigma_w{:});
else
    Sigma_w_full = Sigma_w;
end
if iscell(Sigma_v)
    has_output = ~cellfun(@isempty, Sigma_v);
    Sigma_v_nonempty = Sigma_v(has_output);
    Sigma_v_full = blkdiag(Sigma_v_nonempty{:});
else
    Sigma_v_full = Sigma_v;
end

% 6b. 验证 Σ_Δ = Σ_w + L·Σ_v·L' 的半正定性
Sigma_Delta = Sigma_w_full + L * Sigma_v_full * L';
eig_Sigma_Delta = eig(Sigma_Delta);
min_eig = min(eig_Sigma_Delta);
fprintf('Σ_Δ 最小特征值 = %.6e', min_eig);
if min_eig >= 0
    fprintf('  ✓（半正定）\n');
else
    fprintf('  ✗（存在负特征值）\n');
end
assert(min_eig >= -1e-10, 'Σ_Δ 不是半正定的');

% 6c. 验证误差协方差 Lyapunov 方程的可解性
try
    Sigma_e = dlyap(A_z, Sigma_Delta);
    min_eig_e = min(eig(Sigma_e));
    fprintf('Σ_e 最小特征值 = %.6e', min_eig_e);
    if min_eig_e >= 0
        fprintf('  ✓（半正定）\n');
    else
        fprintf('  ✗（存在负特征值）\n');
    end
    fprintf('✓ 离散 Lyapunov 方程可解\n');
catch ME
    warning('Lyapunov 方程求解失败: %s', ME.message);
end

%% ============================================================
%  7. 汇总
% ============================================================
fprintf('\n===== 测试汇总 =====\n');
fprintf('  所有断言通过。Solve_luenberger_lmi 正确求解 Luenberger 条件，\n');
fprintf('  A_z 满足 Schur 稳定性，可用于分布式残差生成器设计。\n');
