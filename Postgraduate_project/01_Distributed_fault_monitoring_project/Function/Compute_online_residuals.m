function [r_y, r_s] = Compute_online_residuals(k, u, y, s, A_z_omega, L_omega, z_prev)
% Compute_online_residuals  在线并行计算局域残差
%   在时间循环中调用，输入当前步长数据，根据公式 (15)-(16) 迭代计算
%   输出残差 r_y，根据公式 (17)-(18) 并行计算发送信息残差 r_s。
%
%   Inputs:
%       k         - 当前时间步
%       u, y, s   - 当前步的输入、输出、发送信号（cell array 按区域）
%       A_z_omega - 各区域残差发生器状态矩阵（cell array）
%       L_omega   - 各区域观测器增益（cell array）
%       z_prev    - 上一步残差发生器状态（cell array）
%
%   Outputs:
%       r_y - 各区域输出残差（cell array，r_y{omega}）
%       r_s - 各区域发送信息残差（cell array，r_s{omega}）

% TODO: 实现公式 (15)-(18) 的在线残差迭代计算
end
