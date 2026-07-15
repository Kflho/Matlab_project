function [A_z_omega, L_omega, Sigma_r_omega, Sigma_r_all] = Split_matrices_and_cov(A_z, L, indices_omega, Sigma_w, Sigma_v)
% Split_matrices_and_cov  矩阵拆分与协方差计算
%   根据论文公式 (19)，将全局观测器矩阵按行/列块拆分为各计算中心
%   专属的局域矩阵；根据公式 (25)-(26) 计算全局与各区域残差的理论协方差。
%
%   Inputs:
%       A_z, L       - 全局观测器矩阵
%       indices_omega - 各计算中心包含的子系统索引（cell array）
%       Sigma_w, Sigma_v - 噪声协方差矩阵
%
%   Outputs:
%       A_z_omega    - 各区域的局域残差发生器矩阵（cell array）
%       L_omega      - 各区域的局域观测器增益（cell array）
%       Sigma_r_omega - 各区域残差理论协方差（cell array）
%       Sigma_r_all   - 全局残差理论协方差

% TODO: 实现公式 (19) 矩阵拆分、(25)-(26) 协方差计算
end
