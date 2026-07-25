function [G, H, Q_map] = Model_2_to_model_3_qr(A_bar, C_bar, B_bar, D_bar, n_x, n_y)
% Model_2_to_model_3_qr  构建未知输入表示模型（Model 3）
%   根据论文公式 (35)-(36) 组装动态耦合映射矩阵 E_{[i,:]} 和 F_{[i,:]}；
%   使用 QR 分解进行对偶 LQ 分解（公式 (37)-(38)）；提取各子系统
%   的未知输入驱动矩阵 G_i、输出映射 H_i 和全局状态映射 Q_i（公式 (39)）。
%
%   Model 3 动态（公式 (33)-(34)）：
%       x_{i,k+1} = A_i x_{i,k} + B̄_i u_i|_k + G_i d_{i,k} + w_{i,k}
%       y_{i,k}   = C_i x_{i,k} + D̄_i u_i|_k + H_i d_{i,k} + v_{i,k}
%   其中 d_{i,k} = Q_i · x_all,k 为未知输入向量，代表其他子系统状态的综合影响。
%
%   对偶 LQ 分解（公式 (37)-(38)）：
%       E_{[i,:]} x_all = G_i · Q_i · x_all
%       F_{[i,:]} x_all = H_i · Q_i · x_all
%   其中 G_i = L_E（下三角）, Q_i = Q_E（正交行）, H_i = L_F · U_i^T。
%
%   QR 分解（对 E_{[i,:]}^T 做标准 QR，然后转置得到 LQ）：
%       [Q_tmp, R_tmp] = qr(E_{[i,:]}', 0);
%       E_{[i,:]} = R_tmp' * Q_tmp'  →  L_E = R_tmp', Q_E = Q_tmp'
%
%   Inputs:
%       A_bar, C_bar - Model 2 的 2D 分块矩阵（n_s × n_s cell）
%       B_bar, D_bar - Model 2 的 1D 有效矩阵（1 × n_s cell）
%       n_x          - 各子系统状态维度向量（1 × n_s）
%       n_y          - 各子系统输出维度向量（1 × n_s）
%
%   Outputs:
%       G     - 未知输入驱动矩阵，cell array {G_1, ..., G_{n_s}}
%               G{i} 维度为 n_x(i) × dim(d_i)
%       H     - 未知输入→输出映射，cell array {H_1, ..., H_{n_s}}
%               H{i} 维度为 n_y(i) × dim(d_i)，无传感器子系统为 []
%       Q_map - 全局状态→未知输入映射，cell array {Q_1, ..., Q_{n_s}}
%               Q_map{i} 维度为 dim(d_i) × N_x
%
%   Example:
%       [G, H, Q_map] = Model_2_to_model_3_qr(A_bar, C_bar, B_bar, D_bar, n_x, n_y);
%       d_1 = Q_map{1} * x_all;  % 子系统 1 的未知输入

%% ========================================================================
%  1. 维度推断与初始化
% ========================================================================

n_s = length(n_x);
N_x = sum(n_x);

% 累积状态偏移
cum_n_x = [0, cumsum(n_x)];

% 各子系统在全局状态中的行索引
state_rows = cell(1, n_s);
for i = 1:n_s
    state_rows{i} = (cum_n_x(i) + 1) : cum_n_x(i + 1);
end

% 各子系统在全局输出中的行索引（仅针对有传感器的子系统）
cum_n_y = [0, cumsum(n_y)];
output_rows = cell(1, n_s);
for i = 1:n_s
    if n_y(i) > 0
        output_rows{i} = (cum_n_y(i) + 1) : cum_n_y(i + 1);
    else
        output_rows{i} = [];
    end
end

%% ========================================================================
%  2. 公式 (35)-(36)：组装 E_{[i,:]} 和 F_{[i,:]}
% ========================================================================

% E_{[i,:]}：将 A_bar 的第 i 块行对角块置零，保留交叉耦合块
% F_{[i,:]}：将 C_bar 的第 i 块行对角块置零，保留交叉耦合块

E_cell = cell(1, n_s);   % E_{[i,:]}，每个为 n_x(i) × N_x
F_cell = cell(1, n_s);   % F_{[i,:]}，每个为 n_y(i) × N_x

for i = 1:n_s

    % --- 2a. 组装 E_{[i,:]}：取 A_bar 第 i 块行，对角块置零 ---
    row_blocks_E = cell(1, n_s);
    for j = 1:n_s
        if i == j
            % 对角块：置零（自耦不计入未知输入）
            row_blocks_E{j} = zeros(n_x(i), n_x(j));
        else
            % 交叉耦合块：A_bar{i,j} = E_i · M_{ij} · C_{s,j}
            row_blocks_E{j} = A_bar{i, j};
        end
    end
    E_cell{i} = cell2mat(row_blocks_E);   % n_x(i) × N_x

    % --- 2b. 组装 F_{[i,:]}：取 C_bar 第 i 块行，对角块置零 ---
    if n_y(i) > 0
        row_blocks_F = cell(1, n_s);
        for j = 1:n_s
            if i == j
                row_blocks_F{j} = zeros(n_y(i), n_x(j));
            else
                row_blocks_F{j} = C_bar{i, j};
            end
        end
        F_cell{i} = cell2mat(row_blocks_F);   % n_y(i) × N_x
    else
        F_cell{i} = [];   % 无传感器子系统
    end

end

%% ========================================================================
%  3. 公式 (37)-(39)：对偶 LQ 分解与矩阵提取
% ========================================================================

G     = cell(1, n_s);     % G_i：未知输入驱动矩阵
H     = cell(1, n_s);     % H_i：未知输入→输出映射
Q_map = cell(1, n_s);     % Q_i：x_all → d_i 映射

for i = 1:n_s

    % ================================================================
    %  3a. E_{[i,:]} 的 LQ 分解（公式 37）
    %      E_{[i,:]} = L_E · Q_E
    %      对 E_{[i,:]}^T 做经济型 QR： [Q_tmp, R_tmp] = qr(E^T, 0)
    %      则 L_E = R_tmp',  Q_E = Q_tmp'
    % ================================================================

    E_i_mat = E_cell{i};   % n_x(i) × N_x

    % 确定有效秩（排除数值零行）
    tol = 1e-12;
    r_E = rank(E_i_mat, tol);

    if r_E > 0
        % 经济型 QR：对 E^T 分解
        [Q_tmp_E, R_tmp_E] = qr(E_i_mat', 0);   % Q: N_x×r_E, R: r_E×n_x(i)

        % 提取 L_E 和 Q_E
        L_E = R_tmp_E';          % n_x(i) × r_E（下三角的转置，即上三角）
        Q_E = Q_tmp_E';          % r_E × N_x（正交行）

        G{i} = L_E;              % 公式 (39)：G_i = L_{E_{[i,:]}}
    else
        % E_{[i,:]} 为零矩阵 → 无未知输入
        G{i} = zeros(n_x(i), 0);
        Q_E = zeros(0, N_x);
        r_E = 0;
    end

    % ================================================================
    %  3b. F_{[i,:]} 的 LQ 分解（公式 38）
    %      F_{[i,:]} = L_F · Q_F
    % ================================================================

    F_i_mat = F_cell{i};   % n_y(i) × N_x，无传感器子系统为 []

    if ~isempty(F_i_mat) && n_y(i) > 0
        r_F = rank(F_i_mat, tol);

        if r_F > 0
            [Q_tmp_F, R_tmp_F] = qr(F_i_mat', 0);   % Q: N_x×r_F, R: r_F×n_y(i)
            L_F = R_tmp_F';          % n_y(i) × r_F
            Q_F = Q_tmp_F';          % r_F × N_x
        else
            L_F = zeros(n_y(i), 0);
            Q_F = zeros(0, N_x);
            r_F = 0;
        end
    else
        L_F = zeros(0, 0);
        Q_F = zeros(0, N_x);
        r_F = 0;
    end

    % ================================================================
    %  3c. 公式 (39)：建立 d_i 的一致性表达
    %      Q_E = U_i · Q_F,  U_i = Q_E · Q_F^T
    %      Q_i = Q_E（当 Q_F 为非零时验证一致性）
    %
    %      H_i = L_F · U_i^T = L_F · Q_F · Q_E^T
    % ================================================================

    Q_map{i} = Q_E;   % Q_i = Q_{E_{[i,:]}}

    if r_E > 0 && r_F > 0
        % 计算 U_i = Q_E · Q_F^T（r_E × r_F）
        U_i = Q_E * Q_F';

        % H_i = L_F · U_i^T = L_F · (Q_E · Q_F^T)^T
        %     = L_F · Q_F · Q_E^T
        H{i} = L_F * U_i';
    elseif r_E > 0 && r_F == 0
        % F_{[i,:]} 为零 → H_i 不存在，设为零矩阵
        if n_y(i) > 0
            H{i} = zeros(n_y(i), r_E);
        else
            H{i} = [];
        end
    else
        % r_E == 0：无未知输入，H_i 为空
        H{i} = zeros(n_y(i), 0);
    end

end

%% ========================================================================
%  4. 输出维度汇总
% ========================================================================

fprintf('[Model_2_to_model_3_qr] 未知输入模型构建完成（%d 个子系统）：\n', n_s);
for i = 1:n_s
    dim_d_i = size(Q_map{i}, 1);
    fprintf('  子系统 %d: G_i = %d×%d, H_i = %d×%d, dim(d_i) = %d', ...
        i, size(G{i}, 1), size(G{i}, 2), ...
        size(H{i}, 1), size(H{i}, 2), dim_d_i);

    % 检查秩条件：rank(C_i · G_i) = rank(G_i) = rank(H_i) = dim(d_i)
    if dim_d_i > 0 && n_y(i) > 0
        C_i = C_bar{i, i};
        if ~isempty(C_i)
            rank_CG = rank(C_i * G{i}, tol);
            rank_G  = rank(G{i}, tol);
            rank_H  = rank(H{i}, tol);
            if rank_CG == rank_G && rank_G == dim_d_i
                fprintf('  ✓（秩条件满足）\n');
            else
                fprintf('  ⚠（秩条件不满足: rank(CG)=%d, rank(G)=%d, dim(d)=%d）\n', ...
                    rank_CG, rank_G, dim_d_i);
            end
        else
            fprintf('\n');
        end
    else
        fprintf('\n');
    end
end

end
