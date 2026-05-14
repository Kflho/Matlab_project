function Export_fig_paper(figHandle, fileName, widthInch)
% Export_fig_paper  导出高分辨率图片（用于 Word 插入）
%   输入参数：
%       figHandle  : 图窗句柄（例如 gcf）
%       fileName   : 文件名（不含扩展名），建议英文或拼音
%       widthInch  : 图片宽度（英寸），默认 5.5（适合本科论文）
%
%   示例：
%       Export_fig_paper(gcf, 'fig_residual', 5.5);

    if nargin < 3
        widthInch = 5.5;   % 本科论文常用宽度（约14 cm）
    end

    % 设置图窗尺寸（保持纵横比）
    set(figHandle, 'Units', 'inches');
    pos = get(figHandle, 'Position');
    aspectRatio = pos(4) / pos(3);
    heightInch = widthInch * aspectRatio;

    set(figHandle, 'Position', [1 1 widthInch heightInch]);
    set(figHandle, 'PaperPositionMode', 'auto');

    % -- 导出 PNG（推荐，600 dpi 清晰，可直接插入 Word）---
    print(figHandle, [fileName '.png'], '-dpng', '-r600');
    fprintf('已导出：%s.png（%0.1f×%0.1f 英寸）\n', fileName, widthInch, heightInch);

    % -- 可选：同时导出无压缩 TIFF（保证 Word 兼容性）-----
    % print(figHandle, [fileName '.tif'], '-dtiff', '-r600');
    % fprintf('已导出：%s.tif\n', fileName);
end