function x = chi2inv(p, d)
% chi2inv  χ² 分布逆累积分布函数（无需 Statistics Toolbox）
%   使用 base MATLAB 的 gammainc + fzero 实现，等价于 chi2inv(p, d)。
%   若 Statistics Toolbox 可用，优先使用内置 chi2inv。
%
%   Inputs:
%       p - 概率值（标量或向量），0 < p < 1
%       d - 自由度（标量或向量，与 p 同尺寸或标量）
%
%   Outputs:
%       x - χ² 分位数，满足 P(χ²(d) ≤ x) = p
%
%   原理：χ² 分布的 CDF = gammainc(x/2, d/2, 'lower')
%        用 fzero 在 [0, d*20 + 100] 内求解。
%   注意：若 Statistics Toolbox 已安装，MATLAB 内置 chi2inv 路径优先，
%        此文件不会被调用；仅在无 Toolbox 时作为 fallback。

    % 标量展开
    if isscalar(p) && isscalar(d)
        x = solve_single(p, d);
    elseif isscalar(d)
        x = arrayfun(@(pp) solve_single(pp, d), p);
    elseif isscalar(p)
        x = arrayfun(@(dd) solve_single(p, dd), d);
    else
        x = arrayfun(@(pp, dd) solve_single(pp, dd), p, d);
    end
end

function x = solve_single(p, d)
    if p <= 0 || p >= 1
        error('chi2inv: p must be in (0, 1), got p = %.6f', p);
    end
    if d <= 0
        error('chi2inv: d must be positive, got d = %.6f', d);
    end
    % 初值：χ² 均值 = d，上界用 d*20 + 100（覆盖 p≈1 的情况）
    ub = max(d * 20 + 100, 1000);
    f = @(xx) gammainc(xx / 2, d / 2, 'lower') - p;
    try
        x = fzero(f, [0, ub]);
    catch
        % fzero 失败时回退到网格搜索 + 线性插值
        x_grid = linspace(0, ub, 1000);
        cdf_grid = arrayfun(@(xx) gammainc(xx / 2, d / 2, 'lower'), x_grid);
        x = interp1(cdf_grid, x_grid, p, 'linear', 'extrap');
        x = max(0, x);
    end
end
