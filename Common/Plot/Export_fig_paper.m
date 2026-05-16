function Export_fig_paper(figHandle, fileName, widthInch)
    if nargin < 3, widthInch = 5.5; end
    if ~ishandle(figHandle) || ~isvalid(figHandle)
        warning('无效图窗句柄，跳过导出');
        return;
    end
    set(figHandle, 'Units', 'inches');
    pos = get(figHandle, 'Position');
    aspectRatio = pos(4) / pos(3);
    heightInch = widthInch * aspectRatio;
    set(figHandle, 'Position', [1 1 widthInch heightInch]);
    print(figHandle, [fileName '.png'], '-dpng', '-r600');
    fprintf('已导出：%s.png\n', fileName);
end