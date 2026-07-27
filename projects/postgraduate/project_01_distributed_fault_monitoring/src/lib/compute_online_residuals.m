function [r_y, r_s, z_y_all, z_s_all] = compute_online_residuals(...
    u_seq, y_seq, s_cell, ...
    A_z_omega, L_omega, ...
    B_g, C_g, D_g, C_s, D_s, ...
    indices_omega, n_x, n_y, n_s)
% compute_online_residuals  后处理在线残差计算
%   根据论文公式 (15)-(18)，对仿真时间序列进行后处理，计算每个
%   计算中心的输出残差 r^y_{ω,k} 和发送信息残差 r^s_{ω,k}。
%
%   公式 (15)-(16) — 输出残差生成器（由 y_ω 驱动）：
%       z_{ω,k+1} = A_{z,ω}·z_{ω,k} + B_{z,ω}·u_{ω,k} + L_ω·y_{ω,k}
%       r^y_{ω,k}  = y_{ω,k} - C_{g,ω}·z_{ω,k} - D_{g,ω}·u_{ω,k}
%
%   公式 (17)-(18) — 发送信息残差生成器（由 s_ω 驱动）：
%       z^s_{ω,k+1} = A_{z,ω}·z^s_{ω,k} + B_{z,ω}·u_{ω,k} + L_ω·s_{ω,k}
%       r^s_{ω,k}   = s_{ω,k} - C_{s,ω}·z^s_{ω,k} - D_{s,ω}·u_{ω,k}
%
%   Luenberger 条件（T=I, G_z=I）：
%       B_{z,ω} = B_{g,ω} - L_ω·D_{g,ω}
%
%   Inputs:
%       u_seq         - 全局输入时间序列，N_u × T_sim
%       y_seq         - 全局输出时间序列，N_y × T_sim
%       s_cell        - 各子系统信息信号，1×n_s cell
%       A_z_omega     - 各中心局域状态矩阵，1×Ω cell
%       L_omega       - 各中心局域观测器增益，1×Ω cell
%       B_g           - 全局输入矩阵，N_x × N_u
%       C_g           - 全局输出矩阵，N_y × N_x
%       D_g           - 全局前馈矩阵，N_y × N_u
%       C_s           - 各子系统发送信息状态矩阵，1×n_s cell
%       D_s           - 各子系统发送信息前馈矩阵，1×n_s cell
%       indices_omega - 各中心管辖的子系统索引，1×Ω cell
%       n_x           - 各子系统状态维度，1×n_s
%       n_y           - 各子系统输出维度，1×n_s
%       n_s           - 子系统数量
%
%   Outputs:
%       r_y     - 输出残差，1×Ω cell，r_y{ω} 为 dim_y_ω × T_sim
%       r_s     - 发送信息残差，1×Ω cell，r_s{ω} 为 dim_s_ω × T_sim
%       z_y_all - 各中心输出残差发生器状态，1×Ω cell，z{ω} 为 dim_x_ω × T_sim
%       z_s_all - 各中心发送信息残差发生器状态，1×Ω cell

%% ========================================================================
%  1. 预处理：构建索引映射
% ========================================================================

Omega = length(indices_omega);
T_sim = size(u_seq, 2);

% 状态索引映射
cum_n_x = [0, cumsum(n_x)];
state_rows = cell(1, n_s);
for i = 1:n_s
    state_rows{i} = (cum_n_x(i) + 1) : cum_n_x(i + 1);
end

% 输出索引映射
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
%  2. 为各计算中心构建局域矩阵
% ========================================================================

% 预分配
B_z_omega  = cell(1, Omega);   % B_{z,ω}
C_g_omega  = cell(1, Omega);   % C_{g,ω}
D_g_omega  = cell(1, Omega);   % D_{g,ω}
C_s_omega  = cell(1, Omega);   % C_{s,ω}
D_s_omega  = cell(1, Omega);   % D_{s,ω}
L_s_omega  = cell(1, Omega);   % L_{s,ω} = L_ω·C_{g,ω}·pinv(C_{s,ω})

% 每个中心的局域状态/输入/输出维度
dim_x_omega = zeros(1, Omega);
dim_y_omega = zeros(1, Omega);
dim_s_omega = zeros(1, Omega);

% 信号提取的行索引
state_idx_omega = cell(1, Omega);  % 状态行
output_idx_omega = cell(1, Omega); % 输出行

for omega = 1:Omega
    idx = indices_omega{omega};

    % ---- 状态行索引 ----
    rows_x = [];
    for s = idx
        rows_x = [rows_x, state_rows{s}];            %#ok<AGROW>
    end
    state_idx_omega{omega} = rows_x;
    dim_x_omega(omega) = length(rows_x);

    % ---- 输出行索引 ----
    rows_y = [];
    for s = idx
        if ~isempty(output_rows{s})
            rows_y = [rows_y, output_rows{s}];        %#ok<AGROW>
        end
    end
    output_idx_omega{omega} = rows_y;
    dim_y_omega(omega) = length(rows_y);

    % ---- 局域矩阵 ----
    % B_{z,ω} = B_{g,ω} - L_ω · D_{g,ω}
    B_g_omega = B_g(rows_x, :);
    if ~isempty(rows_y)
        D_g_omega{omega} = D_g(rows_y, :);
    else
        D_g_omega{omega} = zeros(0, size(D_g, 2));
    end
    B_z_omega{omega} = B_g_omega - L_omega{omega} * D_g_omega{omega};

    % C_{g,ω}
    if ~isempty(rows_y)
        C_g_omega{omega} = C_g(rows_y, rows_x);
    else
        C_g_omega{omega} = [];
    end

    % C_{s,ω} = blkdiag of C_s for subsystems in center
    C_s_blocks = {};
    D_s_blocks = {};
    dim_s = 0;
    for s = idx
        if ~isempty(C_s{s})
            C_s_blocks{end+1} = C_s{s};                %#ok<AGROW>
            D_s_blocks{end+1} = D_s{s};                %#ok<AGROW>
            dim_s = dim_s + size(C_s{s}, 1);
        end
    end
    if ~isempty(C_s_blocks)
        C_s_omega{omega} = blkdiag(C_s_blocks{:});
        D_s_omega{omega} = vertcat(D_s_blocks{:});
    else
        C_s_omega{omega} = [];
        D_s_omega{omega} = [];
    end
    dim_s_omega(omega) = dim_s;

    % ---- L_{s,ω}：发送信息残差观测器增益 ----
    % 由 Luenberger 条件：A_z = A_g - L·C_g = A_g - L_s·C_s
    % → L_s_ω · C_{s,ω} = L_ω · C_{g,ω}
    % → L_s_ω = L_ω · C_{g,ω} · pinv(C_{s,ω})
    if dim_s > 0 && ~isempty(rows_y) && ~isempty(C_g_omega{omega})
        L_s_omega{omega} = L_omega{omega} * C_g_omega{omega} * pinv(C_s_omega{omega});
    elseif dim_s > 0
        % 无输出测量 → s 残差使用开环预测（L_s = 0）
        L_s_omega{omega} = zeros(dim_x_omega(omega), dim_s);
    else
        L_s_omega{omega} = [];
    end

end

%% ========================================================================
%  3. 预分配存储
% ========================================================================

r_y = cell(1, Omega);
r_s = cell(1, Omega);
z_y_all = cell(1, Omega);
z_s_all = cell(1, Omega);

for omega = 1:Omega
    r_y{omega}     = zeros(dim_y_omega(omega), T_sim);
    r_s{omega}     = zeros(dim_s_omega(omega), T_sim);
    z_y_all{omega} = zeros(dim_x_omega(omega), T_sim + 1);  % 包含初始状态
    z_s_all{omega} = zeros(dim_x_omega(omega), T_sim + 1);
end

%% ========================================================================
%  4. 在线残差计算主循环
% ========================================================================

for omega = 1:Omega

    % 局域矩阵
    Az_w = A_z_omega{omega};
    Bz_w = B_z_omega{omega};
    L_w  = L_omega{omega};
    Cg_w = C_g_omega{omega};
    Dg_w = D_g_omega{omega};
    Cs_w = C_s_omega{omega};
    Ds_w = D_s_omega{omega};

    rows_x = state_idx_omega{omega};
    rows_y = output_idx_omega{omega};

    % 初始状态为零
    z_y_k = zeros(dim_x_omega(omega), 1);
    z_s_k = zeros(dim_x_omega(omega), 1);
    z_y_all{omega}(:, 1) = z_y_k;
    z_s_all{omega}(:, 1) = z_s_k;

    for k = 1:T_sim

        % ---- 提取当前步的局域信号 ----
        u_k = u_seq(:, k);                            % N_u × 1（全局输入）

        if ~isempty(rows_y)
            y_omega_k = y_seq(rows_y, k);             % dim_y_ω × 1
        else
            y_omega_k = [];
        end

        % 局域信息信号 s_ω,k（按子系统拼接）
        s_omega_k = zeros(dim_s_omega(omega), 1);
        offset = 0;
        for s_local = 1:length(indices_omega{omega})
            s_idx = indices_omega{omega}(s_local);
            n_si = n_x(s_idx);                         % C_s 输出维度 = n_x
            s_omega_k(offset + (1:n_si)) = s_cell{s_idx}(:, k);
            offset = offset + n_si;
        end

        % ---- 公式 (15)-(16)：输出残差 ----
        if ~isempty(rows_y) && ~isempty(Cg_w)
            % 残差
            r_y{omega}(:, k) = y_omega_k - Cg_w * z_y_k - Dg_w * u_k;
            % 状态更新（公式 15，L_r = 0）
            z_y_k = Az_w * z_y_k + Bz_w * u_k + L_w * y_omega_k;
        end

        % ---- 公式 (17)-(18)：发送信息残差 ----
        if dim_s_omega(omega) > 0 && ~isempty(Cs_w)
            % 残差
            r_s{omega}(:, k) = s_omega_k - Cs_w * z_s_k - Ds_w * u_k;
            % 状态更新（公式 17，使用 L_{s,ω}，L_r = 0）
            Ls_w = L_s_omega{omega};
            if ~isempty(Ls_w)
                z_s_k = Az_w * z_s_k + Bz_w * u_k + Ls_w * s_omega_k;
            else
                z_s_k = Az_w * z_s_k + Bz_w * u_k;
            end
        end

        % 存储状态
        z_y_all{omega}(:, k+1) = z_y_k;
        z_s_all{omega}(:, k+1) = z_s_k;

    end
end

%% ========================================================================
%  5. 输出汇总
% ========================================================================

fprintf('[compute_online_residuals] 残差计算完成（%d 个中心，%d 步）：\n', Omega, T_sim);
for omega = 1:Omega
    fprintf('  中心 %d: r_y = %d×%d,  r_s = %d×%d\n', ...
        omega, size(r_y{omega}, 1), size(r_y{omega}, 2), ...
        size(r_s{omega}, 1), size(r_s{omega}, 2));
end

end
