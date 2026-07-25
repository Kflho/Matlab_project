function [A_bar, B_bar, C_bar, D_bar, E_bar, F_bar, C_s_bar, D_s_bar] = Model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M, N)
% Model_1_to_model_2  将 Model 1（交互模型）转换为 Model 2（全互连模型）
%   根据论文公式 (7)-(10)，利用邻接矩阵 M 和邻居集 N，将各子系统从局部
%   交互形式转换为全局互连形式。
%
%   Model 1 动态（公式 1-4）：
%       x_{i,k+1} = A_i x_{i,k} + B_i u_{i,k} + E_i t_{i,k} + w_{i,k}
%       y_{i,k}   = C_i x_{i,k} + D_i u_{i,k} + F_i t_{i,k} + v_{i,k}
%       s_{i,k}   = C_{s,i} x_{i,k} + D_{s,i} u_{i,k}
%       t_{i,k}   = Σ_{j∈N_i} M_{ij} s_{j,k}
%
%   Model 2 动态（公式 5-6）：
%       x_{i,k+1} = A_{ii} x_{i,k} + B̄_i u_i|_k + Σ_j A_{ij} x_{j,k} + w_{i,k}
%       y_{i,k}   = C_{ii} x_{i,k} + D̄_i u_i|_k + Σ_j C_{ij} x_{j,k} + v_{i,k}
%
%   Inputs:
%       A, B, C, D, E, F, C_s, D_s - 各子系统的状态空间矩阵（1D cell array）
%       M   - 调制矩阵集合（2D cell array，M{i,j} 为子系统 j → i 的调制）
%       N   - 邻接节点集（1D cell array，N{i} 为子系统 i 的邻居索引向量）
%
%   Outputs:
%       A_bar, C_bar - 2D cell array（n_s × n_s），含子系统间交叉耦合块
%           A_bar{i,i} = A_i                     — 自耦（公式 7）
%           A_bar{i,j} = E_i · M_{ij} · C_{s,j}  — 互耦（公式 7，j ∈ N_i）
%           C_bar{i,i} = C_i                     — 自耦（公式 8）
%           C_bar{i,j} = F_i · M_{ij} · C_{s,j}  — 互耦（公式 8，j ∈ N_i）
%       B_bar, D_bar - 1D cell array，含邻居输入贡献修正后的有效矩阵
%           B̄_i = B_i + E_i · Σ_{j∈N_i} M_{ij} · D_{s,j}   （公式 9）
%           D̄_i = D_i + F_i · Σ_{j∈N_i} M_{ij} · D_{s,j}   （公式 10）
%       E_bar, F_bar, C_s_bar, D_s_bar - 1D cell array，保持 Model 1 原值
%           供下游 Model_2_to_model_3_qr 使用

%% 1. 确定子系统数量与各维度
n_s = length(A);

n_x = zeros(1, n_s);
n_u = zeros(1, n_s);
n_y = zeros(1, n_s);

for i = 1:n_s
    n_x(i) = size(A{i}, 1);
    n_u(i) = size(B{i}, 2);
    if ~isempty(C{i})
        n_y(i) = size(C{i}, 1);
    else
        n_y(i) = 0;
    end
end

%% 2. 初始化输出 cell array

% A_bar, C_bar: 2D cell array（n_s × n_s），非对角块预填零
A_bar = cell(n_s, n_s);
C_bar = cell(n_s, n_s);

for i = 1:n_s
    for j = 1:n_s
        if i == j
            continue;
        end
        A_bar{i,j} = zeros(n_x(i), n_x(j));
        if n_y(i) > 0
            C_bar{i,j} = zeros(n_y(i), n_x(j));
        else
            C_bar{i,j} = [];
        end
    end
end

% B_bar, D_bar: 1D cell array，从 Model 1 的 B, D 初始化
B_bar = cell(1, n_s);
D_bar = cell(1, n_s);
for i = 1:n_s
    B_bar{i} = B{i};
    D_bar{i} = D{i};
end

%% 3. 主循环：按子系统逐行填充公式 (7)-(10)

for i = 1:n_s

    % --- 3a. 对角块：公式 (7)-(8) 的自耦部分 ---
    A_bar{i,i} = A{i};
    C_bar{i,i} = C{i};

    % --- 3b. 遍历邻居，填充交叉耦合块 ---
    for j = N{i}

        % 交叉状态块：公式 (7)
        % A_{ij} = E_i · M_{ij} · C_{s,j}
        if ~isempty(E{i}) && ~isempty(C_s{j})
            A_bar{i,j} = E{i} * M{i,j} * C_s{j};
        end

        % 交叉输出块：公式 (8)
        % C_{ij} = F_i · M_{ij} · C_{s,j}
        if n_y(i) > 0 && ~isempty(F{i}) && ~isempty(C_s{j})
            C_bar{i,j} = F{i} * M{i,j} * C_s{j};
        end

        % 输入修正累积：公式 (9)
        % B̄_i += E_i · M_{ij} · D_{s,j}
        if ~isempty(E{i}) && ~isempty(D_s{j})
            B_bar{i} = B_bar{i} + E{i} * M{i,j} * D_s{j};
        end

        % 前馈修正累积：公式 (10)
        % D̄_i += F_i · M_{ij} · D_{s,j}
        if n_y(i) > 0 && ~isempty(F{i}) && ~isempty(D_s{j})
            D_bar{i} = D_bar{i} + F{i} * M{i,j} * D_s{j};
        end

    end
end

%% 4. 耦合矩阵原样传递（供 Model_2_to_model_3_qr 使用）
E_bar   = E;
F_bar   = F;
C_s_bar = C_s;
D_s_bar = D_s;

end
