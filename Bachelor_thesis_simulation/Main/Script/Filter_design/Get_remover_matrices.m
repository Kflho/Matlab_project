function [Gq, Hq, Cq, Dq] = Get_remover_matrices(Gw, Hw, Cw, Dw)
% GET_REMOVER_MATRICES 根据水印嵌入器的状态空间求解移除器的状态空间
%
% 输入参数:
%   Gw, Hw, Cw, Dw - 水印嵌入器的状态空间矩阵
%
% 输出参数:
%   Gq, Hq, Cq, Dq - 水印移除器的状态空间矩阵

    % 1. 检查 Dw 矩阵是否可逆 (即行列式是否接近于0)
    % D_w 必须是方阵且满秩才能求逆 D_w^{-1}
    if cond(Dw) > 1e10
        warning('矩阵 Dw 的条件数过大，可能接近奇异阵，求逆可能导致数值不稳定。');
    end
    
    % 2. 计算 Dw 的逆矩阵
    inv_Dw = inv(Dw);
    
    % 3. 根据公式计算移除器矩阵
    % Dq = Dw^{-1}
    Dq = inv_Dw;
    
    % Cq = -Dw^{-1} * Cw
    Cq = -inv_Dw * Cw;
    
    % Hq = Hw * Dw^{-1}
    Hq = Hw * inv_Dw;
    
    % Gq = Gw - Hw * Dw^{-1} * Cw
    Gq = Gw - Hw * inv_Dw * Cw;

end