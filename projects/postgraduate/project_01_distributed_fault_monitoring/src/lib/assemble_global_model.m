function [A_g, B_g, C_g, D_g] = assemble_global_model(A_bar, B_bar, C_bar, D_bar, n_vec)
% assemble_global_model  组装全局大矩阵
%   根据论文公式 (11)-(14)，将各子系统的 Model 2 矩阵组装为全厂大系统
%   的动态方程矩阵 A_g, B_g, C_g, D_g。
%
%   公式 (11)：B = {B_{ij}}, D = {D_{ij}}  — 分块定义
%   公式 (12)：ξ = [ξ_1; ...; ξ_{n_s}], Ξ = [Ξ_{ij}]  — 向量堆叠与块矩阵拼接
%   公式 (13)：x_{k+1} = A x_k + B u_k + w_k
%   公式 (14)：y_k     = C x_k + D u_k + v_k
%
%   Inputs:
%       A_bar, C_bar - 2D cell array（n_s × n_s），交叉耦合分块
%           A_bar{i,j}: n_x(i) × n_x(j)
%           C_bar{i,j}: n_y(i) × n_x(j)（无输出子系统对应行为 []）
%       B_bar, D_bar - 1D cell array（1 × n_s），各子系统的有效输入/前馈矩阵
%           B_bar{i}: n_x(i) × n_u(i)
%           D_bar{i}: n_y(i) × n_u(i)（无输出子系统为 []）
%       n_vec - 各子系统状态维度向量（1 × n_s）
%
%   Outputs:
%       A_g - 全局状态矩阵（Σn_x × Σn_x）
%       B_g - 全局输入矩阵（Σn_x × n_u）  — 共享输入时各子系统 n_u 相同
%       C_g - 全局输出矩阵（Σn_y × Σn_x）  — 跳过无输出子系统
%       D_g - 全局前馈矩阵（Σn_y × n_u）

%% 1. 维度推断
n_s = size(A_bar, 1);
n_x = n_vec;

n_u = zeros(1, n_s);
n_y = zeros(1, n_s);
for i = 1:n_s
    n_u(i) = size(B_bar{i}, 2);
    if ~isempty(C_bar{i,i})
        n_y(i) = size(C_bar{i,i}, 1);
    end
end

%% 2. 组装 A_g：2D 分块水平+垂直拼接（公式 12）

A_g = cell2mat(A_bar);              % (Σn_x) × (Σn_x)

%% 3. 组装 B_g：1D 有效矩阵垂直堆叠（公式 9, 13）

B_g = vertcat(B_bar{:});            % (Σn_x) × n_u_common

%% 4. 组装 C_g：筛选有输出子系统行后，2D 分块拼接（公式 12, 14）

has_output = (n_y > 0);

if any(has_output)
    C_g = cell2mat(C_bar(has_output, :));  % (Σn_y) × (Σn_x)
else
    C_g = [];
end

%% 5. 组装 D_g：筛选有输出子系统的 1D 有效矩阵垂直堆叠（公式 10, 14）

if any(has_output)
    D_g = vertcat(D_bar{has_output});      % (Σn_y) × n_u_common
else
    D_g = [];
end

end
