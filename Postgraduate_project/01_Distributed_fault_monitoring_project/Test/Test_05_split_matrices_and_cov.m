%% Test_04_split_matrices_and_cov.m  矩阵拆分与协方差计算测试
%  通过完整离线设计链路获取 A_z/L，调用 Split_matrices_and_cov
%  拆分为局域矩阵并计算理论协方差，验证：
%    1. 公式 (19)：A_z_omega 和 L_omega 的维度与索引正确性
%    2. 公式 (25)：稳态误差协方差 Σ_e 的半正定性
%    3. 公式 (26)：Σ_r_all 与 Σ_r_omega 的维度与结构正确性
%    4. 分块一致性：Σ_r_all 的分块可还原为 Σ_r_omega

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../Common/'));
addpath(genpath('../Function/'));
addpath(genpath('../Script/'));

%% ============================================================
%  1. 完整离线设计链路：Model 1 → Model 2 → Global → LMI
% ============================================================
fprintf('===== 1. 离线设计链路 =====\n\n');

Create_model_1;

[A_bar, B_bar, C_bar, D_bar] = ...
    Model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M, N);

n_x = [1, 1, 1, 1];
[A_g, B_g, C_g, D_g] = Assemble_global_model(A_bar, B_bar, C_bar, D_bar, n_x);

[A_z, L] = Solve_luenberger_lmi(A_g, C_g, Sigma_w, Sigma_v);

fprintf('A_g = %d×%d, C_g = %d×%d\n', size(A_g, 1), size(A_g, 2), ...
    size(C_g, 1), size(C_g, 2));

%% ============================================================
%  2. 配置计算中心划分
% ============================================================
fprintf('\n===== 2. 计算中心配置 =====\n\n');

Omega = 2;
indices_omega = {[1, 3], [2, 4]};
fprintf('Omega = %d\n', Omega);
fprintf('中心 1: 子系统 %s\n', mat2str(indices_omega{1}));
fprintf('中心 2: 子系统 %s\n', mat2str(indices_omega{2}));

%% ============================================================
%  3. 调用 Split_matrices_and_cov（含 C_g 精确计算）
% ============================================================
fprintf('\n===== 3. Split_matrices_and_cov（精确 C_g）=====\n\n');

[A_z_omega, L_omega, Sigma_r_omega, Sigma_r_all] = ...
    Split_matrices_and_cov(A_z, L, indices_omega, Sigma_w, Sigma_v, C_g);

%% ============================================================
%  4. 验证公式 (19)：局域矩阵维度
% ============================================================
fprintf('\n===== 4. 验证公式 (19)：局域矩阵维度 =====\n\n');

% 中心 1 管辖子系统 1,3：n_x(1)=1, n_x(3)=1 → 局域状态维度 = 2
% 中心 1 管辖的传感器：仅子系统 1 (n_y=1) → 局域输出维度 = 1
assert(isequal(size(A_z_omega{1}), [2, 2]), ...
    'A_z_omega{1} 应为 2×2（子系统 1,3 各 1 状态）');
assert(isequal(size(L_omega{1}), [2, 1]), ...
    'L_omega{1} 应为 2×1（2 状态行 × 子系统 1 的 1 传感器）');

% 中心 2 管辖子系统 2,4：n_x(2)=1, n_x(4)=1 → 局域状态维度 = 2
% 中心 2 管辖的传感器：仅子系统 2 (n_y=1) → 局域输出维度 = 1
assert(isequal(size(A_z_omega{2}), [2, 2]), ...
    'A_z_omega{2} 应为 2×2（子系统 2,4 各 1 状态）');
assert(isequal(size(L_omega{2}), [2, 1]), ...
    'L_omega{2} 应为 2×1（2 状态行 × 子系统 2 的 1 传感器）');

fprintf('✓ 局域矩阵维度全部正确\n');
fprintf('  A_z_omega{1} = %d×%d, L_omega{1} = %d×%d\n', ...
    size(A_z_omega{1}, 1), size(A_z_omega{1}, 2), ...
    size(L_omega{1}, 1), size(L_omega{1}, 2));
fprintf('  A_z_omega{2} = %d×%d, L_omega{2} = %d×%d\n', ...
    size(A_z_omega{2}, 1), size(A_z_omega{2}, 2), ...
    size(L_omega{2}, 1), size(L_omega{2}, 2));

%% ============================================================
%  5. 验证公式 (19)：局域矩阵内容正确性
% ============================================================
fprintf('\n===== 5. 验证公式 (19)：局域矩阵内容 =====\n\n');

% 5a. A_z_omega{1} = A_z([1,3], [1,3])
A_z_block_1 = A_z([1, 3], [1, 3]);
err_Az_block_1 = max(abs(A_z_omega{1}(:) - A_z_block_1(:)));
fprintf('max|A_z_omega{1} - A_z([1,3],[1,3])| = %.2e\n', err_Az_block_1);
assert(err_Az_block_1 < 1e-14, 'A_z_omega{1} 块提取错误');

% 5b. A_z_omega{2} = A_z([2,4], [2,4])
A_z_block_2 = A_z([2, 4], [2, 4]);
err_Az_block_2 = max(abs(A_z_omega{2}(:) - A_z_block_2(:)));
fprintf('max|A_z_omega{2} - A_z([2,4],[2,4])| = %.2e\n', err_Az_block_2);
assert(err_Az_block_2 < 1e-14, 'A_z_omega{2} 块提取错误');

% 5c. L_omega{1} = L([1,3], 1)  — 子系统 1 的传感器列
L_block_1 = L([1, 3], 1);
err_L_block_1 = max(abs(L_omega{1}(:) - L_block_1(:)));
fprintf('max|L_omega{1} - L([1,3],1)| = %.2e\n', err_L_block_1);
assert(err_L_block_1 < 1e-14, 'L_omega{1} 块提取错误');

% 5d. L_omega{2} = L([2,4], 2)  — 子系统 2 的传感器列
L_block_2 = L([2, 4], 2);
err_L_block_2 = max(abs(L_omega{2}(:) - L_block_2(:)));
fprintf('max|L_omega{2} - L([2,4],2)| = %.2e\n', err_L_block_2);
assert(err_L_block_2 < 1e-14, 'L_omega{2} 块提取错误');

fprintf('✓ 所有局域矩阵内容与手动索引提取一致\n');

%% ============================================================
%  6. 验证局域 A_z_omega 的 Schur 稳定性
% ============================================================
fprintf('\n===== 6. 验证局域 A_z_omega 的 Schur 稳定性 =====\n\n');

for omega = 1:Omega
    abs_eig = abs(eig(A_z_omega{omega}));
    fprintf('中心 %d: max|λ| = %.6f', omega, max(abs_eig));
    if all(abs_eig < 1)
        fprintf('  ✓\n');
    else
        fprintf('  ✗（非 Schur 稳定！）\n');
        warning('A_z_omega{%d} 不是 Schur 稳定的。全局 A_z 稳定未必保证局部块稳定。', omega);
    end
end

%% ============================================================
%  7. 验证公式 (25)：稳态误差协方差 Σ_e
% ============================================================
fprintf('\n===== 7. 验证公式 (25)：稳态误差协方差 =====\n\n');

% 手动重建 Σ_e 验证
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

Sigma_Delta = Sigma_w_full + L * Sigma_v_full * L';
Sigma_e = dlyap(A_z, Sigma_Delta);

% 验证 Σ_e 的半正定性（Σ_e 在函数内部计算，这里手动验证）
eig_Se = eig(Sigma_e);
fprintf('Σ_e 特征值范围：[%.6e, %.6e]\n', min(eig_Se), max(eig_Se));
assert(all(eig_Se >= -1e-10), 'Σ_e 不是半正定的');
fprintf('✓ Σ_e 是半正定的\n');

%% ============================================================
%  8. 验证公式 (26)：残差协方差 Σ_r_all 和 Σ_r_omega
% ============================================================
fprintf('\n===== 8. 验证公式 (26)：残差协方差 =====\n\n');

% 8a. Σ_r_all 维度：N_y × N_y = 2×2
assert(isequal(size(Sigma_r_all), [2, 2]), ...
    'Σ_r_all 应为 2×2（2 个传感器输出）');
fprintf('Σ_r_all = %d×%d\n', size(Sigma_r_all, 1), size(Sigma_r_all, 2));

% 8b. Σ_r_all 半正定性
eig_Sr_all = eig(Sigma_r_all);
fprintf('Σ_r_all 特征值：[%.6e, %.6e]\n', min(eig_Sr_all), max(eig_Sr_all));
assert(all(eig_Sr_all >= -1e-10), 'Σ_r_all 不是半正定的');
fprintf('✓ Σ_r_all 是半正定的\n');

% 8c. 手动计算 Σ_r_all 验证
Sigma_r_all_expected = C_g * Sigma_e * C_g' + Sigma_v_full;
err_Sr_all = max(abs(Sigma_r_all(:) - Sigma_r_all_expected(:)));
fprintf('max|Σ_r_all - (C_g·Σ_e·C_g'' + Σ_v)| = %.2e\n', err_Sr_all);
assert(err_Sr_all < 1e-10, 'Σ_r_all 计算方法不一致');
fprintf('✓ Σ_r_all 计算正确\n');

% 8d. Σ_r_omega 维度
fprintf('\nΣ_r_omega 维度：\n');
for omega = 1:Omega
    fprintf('  中心 %d: %d×%d', omega, ...
        size(Sigma_r_omega{omega}, 1), size(Sigma_r_omega{omega}, 2));
    % 每个中心有 1 个传感器
    assert(isequal(size(Sigma_r_omega{omega}), [1, 1]), ...
        sprintf('Σ_r_omega{%d} 应为 1×1', omega));
    fprintf('  ✓\n');
end

% 8e. Σ_r_omega 半正定性
for omega = 1:Omega
    eig_Sr_w = eig(Sigma_r_omega{omega});
    assert(all(eig_Sr_w >= -1e-12), ...
        sprintf('Σ_r_omega{%d} 不是半正定的', omega));
end
fprintf('✓ 所有 Σ_r_omega 半正定\n');

% 8f. 分块一致性：Σ_r_omega{1} 和 Σ_r_omega{2} 应分别为 Σ_r_all 的对角子块
% （在当前结构中，子系统 1 对应 Σ_r_all(1,1)，子系统 2 对应 Σ_r_all(2,2)）
assert(abs(Sigma_r_omega{1} - Sigma_r_all(1, 1)) < 1e-14, ...
    'Σ_r_omega{1} 应与 Σ_r_all(1,1) 一致');
assert(abs(Sigma_r_omega{2} - Sigma_r_all(2, 2)) < 1e-14, ...
    'Σ_r_omega{2} 应与 Σ_r_all(2,2) 一致');
fprintf('✓ Σ_r_omega 与 Σ_r_all 的分块一致性成立\n');

%% ============================================================
%  9. 验证无 C_g 回退模式
% ============================================================
fprintf('\n===== 9. 验证无 C_g 回退模式 =====\n\n');

[~, ~, Sr_om_fallback, Sr_all_fallback] = ...
    Split_matrices_and_cov(A_z, L, indices_omega, Sigma_w, Sigma_v);

% 回退模式下 Σ_r_all = Σ_e（4×4，状态维度）
assert(isequal(size(Sr_all_fallback), [4, 4]), ...
    '回退模式 Σ_r_all 应为 4×4（= Σ_e）');
fprintf('回退模式 Σ_r_all 维度 = %d×%d（= Σ_e）\n', ...
    size(Sr_all_fallback, 1), size(Sr_all_fallback, 2));

% 回退模式下 Σ_r_omega 维度 = 中心管辖的状态维度
for omega = 1:Omega
    assert(isequal(size(Sr_om_fallback{omega}), [2, 2]), ...
        sprintf('回退模式 Σ_r_omega{%d} 应为 2×2', omega));
    fprintf('  中心 %d: %d×%d  ✓\n', omega, ...
        size(Sr_om_fallback{omega}, 1), size(Sr_om_fallback{omega}, 2));
end

fprintf('✓ 无 C_g 回退模式正常工作\n');

%% ============================================================
%  10. 汇总
% ============================================================
fprintf('\n===== 测试汇总 =====\n');
fprintf('  所有断言通过。Split_matrices_and_cov 正确实现：\n');
fprintf('    - 公式 (19)：矩阵分块拆分\n');
fprintf('    - 公式 (25)：离散 Lyapunov 方程求解 Σ_e\n');
fprintf('    - 公式 (26)：全局与局域残差理论协方差计算\n');
fprintf('  可用于后续在线残差生成和 T² 检测阈值设定。\n');
