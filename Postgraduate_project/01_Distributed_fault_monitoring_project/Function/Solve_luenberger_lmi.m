function [A_z, L] = Solve_luenberger_lmi(A_g, C_g, Sigma_w, Sigma_v)
% Solve_luenberger_lmi  求解 Luenberger 观测器参数矩阵
%   调用 YALMIP 或 LMI 工具箱，求解满足 Theorem 1 中 Luenberger 条件的
%   全局矩阵 A_z 和观测器增益 L，并验证 A_z 的 Schur 稳定性。
%
%   Inputs:
%       A_g, C_g   - 全局系统矩阵
%       Sigma_w    - 过程噪声协方差矩阵
%       Sigma_v    - 测量噪声协方差矩阵
%
%   Outputs:
%       A_z - 残差发生器状态矩阵（需 Schur 稳定）
%       L   - 观测器增益矩阵

% TODO: 求解 LMI，构造 A_z，验证 eig(A_z) 在单位圆内
end
