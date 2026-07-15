function [x_hat, d_hat, Sigma_x_tilde, M_gain, K_gain] = Recursive_joint_filter(k, y, u, G, Q_map, x_prev, Sigma_prev)
% Recursive_joint_filter  改进型递归滤波器
%   实现前向五步联合估计算法：
%     公式 (40)-(41)：计算偏置创新向量，解算未知输入估计 d_hat
%     公式 (42)-(44)：计算无偏创新向量，更新最小方差状态估计 x_hat
%     公式 (45)-(47)：在线更新滤波器增益 M, K 及误差协方差 Sigma_x_tilde
%
%   Inputs:
%       k          - 当前时间步
%       y, u       - 当前测量输出与输入
%       G, Q_map   - 未知输入模型矩阵（来自 Model_2_to_model_3_qr）
%       x_prev     - 上一步状态估计
%       Sigma_prev - 上一步误差协方差
%
%   Outputs:
%       x_hat        - 当前步状态最小方差估计
%       d_hat        - 未知输入估计
%       Sigma_x_tilde - 误差协方差矩阵
%       M_gain, K_gain - 滤波器增益矩阵

% TODO: 实现公式 (40)-(47) 的递归滤波逻辑
end
