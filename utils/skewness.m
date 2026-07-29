function s = skewness(x, flag)
% skewness  sample skewness of a vector or matrix (fallback).
%   s = skewness(x)
%   s = skewness(x, flag)
%
%   returns the sample skewness of the elements in x.
%   - if x is a vector: scalar skewness.
%   - if x is a matrix: row vector of column skewnesses.
%
%   flag = 0 (default): bias-corrected (uses n-1 in denominator).
%   flag = 1: uncorrected (uses n in denominator).
%
%   formula:
%     s = (1/n * sum((x - mean(x)).^3)) / (std(x,flag))^3
%
%   use this when statistics and machine learning toolbox is unavailable.

if nargin < 2
    flag = 0;
end

if isvector(x)
    n = length(x);
    mu = mean(x);
    sigma = std(x, flag);
    if sigma < eps
        s = 0;
    else
        s = mean((x - mu).^3) / sigma^3;
    end
    % apply bias correction for flag=0
    if flag == 0 && n > 2
        s = s * sqrt(n*(n-1)) / (n-2);
    end
else
    % matrix: operate column-wise
    [m_rows, n_cols] = size(x);
    s = zeros(1, n_cols);
    for j = 1:n_cols
        col = x(:, j);
        col = col(~isnan(col));  % remove NaN
        n = length(col);
        if n < 3
            s(j) = NaN;
        else
            mu = mean(col);
            sigma = std(col, flag);
            if sigma < eps
                s(j) = 0;
            else
                s(j) = mean((col - mu).^3) / sigma^3;
                if flag == 0
                    s(j) = s(j) * sqrt(n*(n-1)) / (n-2);
                end
            end
        end
    end
end

end
