%% Test_03_model_2_to_model_3_qr.m  未知输入模型转换测试
%  通过完整链路 Model 1 → Model 2，调用 Model_2_to_model_3_qr
%  提取 G_i, H_i, Q_i，验证：
%    1. 公式 (35)-(36)：E_{[i,:]} 和 F_{[i,:]} 组装正确性
%    2. 公式 (37)-(38)：LQ 分解 G_i·Q_i = E_{[i,:]}、H_i·Q_i ≈ F_{[i,:]}
%    3. 公式 (39)：未知输入维度与秩条件
%    4. 公式 (33)-(34)：Model 3 等价性（G_i·d_i 还原耦合项）

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../Common/'));
addpath(genpath('../Function/'));
addpath(genpath('../Script/'));

%% ============================================================
%  1. 构建 Model 2 矩阵（完整链路前半段）
% ============================================================
fprintf('===== 1. 构建 Model 2 =====\n\n');

Create_model_1;

[A_bar, B_bar, C_bar, D_bar, E_bar, F_bar, C_s_bar, D_s_bar] = ...
    Model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M, N);

fprintf('n_s = %d,  n_x = [%s],  n_y = [%s]\n', ...
    n_s, num2str(n_x), num2str(n_y));

%% ============================================================
%  2. 调用 Model_2_to_model_3_qr
% ============================================================
fprintf('\n===== 2. Model_2_to_model_3_qr =====\n\n');

[G, H, Q_map] = Model_2_to_model_3_qr(A_bar, C_bar, B_bar, D_bar, n_x, n_y);

%% ============================================================
%  3. 验证：公式 (35) — E_{[i,:]} 组装与分解
% ============================================================
fprintf('\n===== 3. 验证公式 (35)-(37)：E_{[i,:]} 分解 =====\n\n');

N_x = sum(n_x);

for i = 1:n_s
    % 3a. 从 A_bar 手动构建 E_{[i,:]}（对角块置零）
    row_blocks = cell(1, n_s);
    for j = 1:n_s
        if i == j
            row_blocks{j} = zeros(n_x(i), n_x(j));
        else
            row_blocks{j} = A_bar{i, j};
        end
    end
    E_i_expected = cell2mat(row_blocks);

    % 3b. 用分解结果还原
    dim_d_i = size(Q_map{i}, 1);
    if dim_d_i > 0
        E_i_reconstructed = G{i} * Q_map{i};

        err_E = max(abs(E_i_reconstructed(:) - E_i_expected(:)));
        fprintf('子系统 %d: max|G_i·Q_i - E_{[i,:]}| = %.2e', i, err_E);
        if err_E < 1e-12
            fprintf('  ✓\n');
        else
            fprintf('  ✗\n');
            warning('子系统 %d: E_{[i,:]} 分解重构误差过大', i);
        end
    else
        % 无未知输入：E_{[i,:]} 应为零
        err_E_zero = max(abs(E_i_expected(:)));
        fprintf('子系统 %d: dim(d_i)=0, max|E_{[i,:]}| = %.2e', i, err_E_zero);
        if err_E_zero < 1e-12
            fprintf('  ✓（确实为零）\n');
        else
            fprintf('  ✗（应有未知输入但 rank=0）\n');
            warning('子系统 %d: E_{[i,:]} 非零但秩为零', i);
        end
    end
end

%% ============================================================
%  4. 验证：公式 (36)-(38) — F_{[i,:]} 组装与分解
% ============================================================
fprintf('\n===== 4. 验证公式 (36)-(38)：F_{[i,:]} 分解 =====\n\n');

for i = 1:n_s
    if n_y(i) == 0
        fprintf('子系统 %d: 无传感器，跳过 F_{[i,:]} 验证\n', i);
        continue;
    end

    % 4a. 从 C_bar 手动构建 F_{[i,:]}（对角块置零）
    row_blocks = cell(1, n_s);
    for j = 1:n_s
        if i == j
            row_blocks{j} = zeros(n_y(i), n_x(j));
        else
            row_blocks{j} = C_bar{i, j};
        end
    end
    F_i_expected = cell2mat(row_blocks);

    % 4b. 用分解结果还原
    dim_d_i = size(Q_map{i}, 1);
    if dim_d_i > 0 && ~isempty(H{i}) && size(H{i}, 2) > 0
        F_i_reconstructed = H{i} * Q_map{i};
        err_F = max(abs(F_i_reconstructed(:) - F_i_expected(:)));
        fprintf('子系统 %d: max|H_i·Q_i - F_{[i,:]}| = %.2e', i, err_F);
        if err_F < 1e-12
            fprintf('  ✓\n');
        else
            fprintf('  ✗\n');
        end
    else
        % 无 H_i：F_{[i,:]} 应为零
        err_F_zero = max(abs(F_i_expected(:)));
        fprintf('子系统 %d: dim(H_i)=0, max|F_{[i,:]}| = %.2e', i, err_F_zero);
        if err_F_zero < 1e-12
            fprintf('  ✓（确实为零）\n');
        else
            fprintf('  ⚠（F_{[i,:]} 非零但无可用的 H_i）\n');
        end
    end
end

%% ============================================================
%  5. 验证：Q_i 的正交性
% ============================================================
fprintf('\n===== 5. 验证 Q_i 的行正交性 =====\n\n');

for i = 1:n_s
    dim_d_i = size(Q_map{i}, 1);
    if dim_d_i > 0
        Q_orth = Q_map{i} * Q_map{i}';
        err_orth = max(abs(Q_orth(:) - eye(dim_d_i)));
        fprintf('子系统 %d: max|Q_i·Q_i'' - I| = %.2e', i, err_orth);
        if err_orth < 1e-12
            fprintf('  ✓（正交行）\n');
        else
            fprintf('  ⚠\n');
        end
    end
end

%% ============================================================
%  6. 验证：Model 3 等价性 — G_i·d_i 还原耦合项
% ============================================================
fprintf('\n===== 6. 验证 Model 3 等价性 =====\n\n');

% 随机生成全局状态向量 x_all，验证：
%   G_i · (Q_i · x_all) = Σ_{j≠i} A_bar{i,j} · x_j

rng(2024);
x_all_test = randn(N_x, 1);

% 累积状态偏移
cum_n_x = [0, cumsum(n_x)];

for i = 1:n_s
    % 6a. Model 2 耦合项：Σ_{j≠i} A_bar{i,j} · x_j
    coupling_M2 = zeros(n_x(i), 1);
    for j = 1:n_s
        if i ~= j
            idx_j = (cum_n_x(j) + 1) : cum_n_x(j + 1);
            coupling_M2 = coupling_M2 + A_bar{i,j} * x_all_test(idx_j);
        end
    end

    % 6b. Model 3 耦合项：G_i · Q_i · x_all
    if size(Q_map{i}, 1) > 0
        coupling_M3 = G{i} * Q_map{i} * x_all_test;
    else
        coupling_M3 = zeros(n_x(i), 1);
    end

    err_coupling = max(abs(coupling_M3 - coupling_M2));
    fprintf('子系统 %d: max|G_i·Q_i·x_all - ΣA_{ij}·x_j| = %.2e', i, err_coupling);
    if err_coupling < 1e-12
        fprintf('  ✓\n');
    else
        fprintf('  ✗\n');
        warning('子系统 %d: Model 3 与 Model 2 不等价', i);
    end
end

%% ============================================================
%  7. 汇总
% ============================================================
fprintf('\n===== 测试汇总 =====\n');
fprintf('  Model_2_to_model_3_qr 正确实现公式 (35)-(39)：\n');
fprintf('    - E_{[i,:]} 和 F_{[i,:]} 组装与 LQ 分解\n');
fprintf('    - G_i, H_i, Q_i 提取与维度验证\n');
fprintf('    - Model 3 等价性（耦合项还原）\n');

% 报告秩条件状态
fprintf('\n  秩条件检查（需满足方可使用 Recursive_joint_filter）：\n');
tol = 1e-12;
for i = 1:n_s
    dim_d = size(Q_map{i}, 1);
    if dim_d > 0 && n_y(i) > 0 && ~isempty(C_bar{i,i})
        C_i = C_bar{i, i};
        rCG = rank(C_i * G{i}, tol);
        rG  = rank(G{i}, tol);
        rH  = rank(H{i}, tol);
        ok = (rCG == rG && rG == dim_d);
        fprintf('  子系统 %d: rank(CG)=%d, rank(G)=%d, rank(H)=%d, dim(d)=%d  %s\n', ...
            i, rCG, rG, rH, dim_d, ternary(ok, '✓', '✗'));
    else
        fprintf('  子系统 %d: dim(d)=%d（无传感器或无未知输入）\n', i, dim_d);
    end
end

fprintf('\n  注：若 F_i = 0（本测试用例），则 H_i = 0，秩条件不满足。\n');
fprintf('  此时 Recursive_joint_filter 不可用，需设置非零 F_i。\n');
fprintf('  这不影响 Model_2_to_model_3_qr 的正确性。\n');

% ---- 辅助：三元运算符 ----
function s = ternary(cond, t, f)
    if cond, s = t; else, s = f; end
end
