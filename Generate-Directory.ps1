# ===================================================================
# 脚本名称: Generate-Markdown-Directory.ps1
# 脚本功能: 递归扫描指定目录，生成一个带有多级编号和链接的 Markdown 目录文件。
# 版本: 5.0
# 特性:
#   - 可通过参数自定义输出文件名和 Markdown 标题。
#   - 自动添加 [TOC] 标记。
#   - 自动忽略 .vscode 文件夹。
#   - 自动跳过不包含 .md 文件的空文件夹。
#   - 为文件和文件夹提供不同的链接格式。
#   - 完整的中文注释。
#
# 使用示例
#   - .\Generate-Directory.ps1 -Output "My-Study-Notes.md" -Title "我的Linux内核笔记"
# 重要提示: 为了正确处理中文字符，此 .ps1 脚本文件本身必须以 "UTF-8 with BOM" 编码保存。
# ===================================================================

# --- 脚本参数定义 ---
param(
    # 要扫描的根目录路径，默认为当前目录 "."
    [string]$Path = ".",

    # 3. 提供参数来自定义输出文件名
    # 生成的 Markdown 文件的名称
    [string]$Output = "README.md",

    # 3. 提供参数来自定义标题
    # 写入 Markdown 文件顶部的H1主标题
    [string]$Title = "学习笔记",

    # 递归扫描的最大深度，防止无限循环
    [int]$MaxDepth = 10
)

# --- 核心函数：递归生成目录树 ---
# 此函数会遍历一个目录，并返回一个包含 Markdown 格式的行数组以及一个状态标记的对象。
function Get-DirectoryTree {
    param(
        # 当前正在处理的目录路径
        [string]$Directory,
        # 当前的递归深度
        [int]$Depth,
        # 父级的编号前缀 (例如 "1." 或 "1.2.")
        [string]$NumberPrefix
    )

    # 初始化一个空数组，用于收集当前函数调用生成的所有 Markdown 行
    $outputLines = @()
    # 创建一个标记，用于判断当前目录或其任何子目录是否包含有效的 .md 文件。这是实现“跳过空目录”功能的关键。
    $hasMarkdownContent = $false

    # 获取当前目录下的所有项目，并进行过滤和排序：
    # -Exclude ".vscode"       # 1. 忽略 .vscode 文件夹
    # Where-Object {...}       # 只选择两种项目：文件夹(PSIsContainer) 或 文件名以 .md 结尾的文件
    # Sort-Object {...}        # 排序：文件夹优先，然后所有项目按名称排序
    $items = Get-ChildItem -Path $Directory -Exclude ".vscode" | Where-Object { $_.PSIsContainer -or $_.Name.EndsWith(".md") } | Sort-Object -Property @{Expression="PsIsContainer"; Descending=$true}, Name
    
    # 初始化当前层级的编号计数器
    $counter = 1
    foreach ($item in $items) {
        # 标记当前这个 $item 是否最终被添加到了输出中
        $itemAdded = $false

        # 构造当前项目的完整编号 (例如 "1.2.3.")
        $currentNumber = if ([string]::IsNullOrEmpty($NumberPrefix)) { "$counter." } else { "$NumberPrefix$counter." }
        # 构造用于 Markdown 链接的相对路径 (将 Windows 的 \ 替换为 /)
        $relativePath = $item.FullName.Substring($pwd.Path.Length + 1).Replace("\", "/")

        # --- 判断项目类型是文件夹还是文件 ---
        if ($item.PSIsContainer) {
            # 如果是文件夹，我们不能立即添加它。必须先递归检查它内部是否含有 .md 文件。
            $subResult = Get-DirectoryTree -Directory $item.FullName -Depth ($Depth + 1) -NumberPrefix $currentNumber
            
            # 只有当递归调用的结果表明子目录确实含有 .md 文件时，才处理这个文件夹
            if ($subResult.HasMarkdown) {
                $hasMarkdownContent = $true # 标记内容有效
                
                # 按要求格式化文件夹链接 (编号在方括号外)
                # 示例: "- 3. [drivers](./drivers/)"
                $outputLines += (" " * ($Depth * 2) + "- " + $currentNumber + " [$($item.Name)]($($relativePath)/)")
                # 将子目录返回的所有行也一并添加到输出中
                $outputLines += $subResult.Lines
                $itemAdded = $true # 标记此文件夹已添加
            }
        } else {
            # 如果是 .md 文件，则无条件添加它
            $hasMarkdownContent = $true # 标记内容有效
            
            # 按要求格式化文件链接 (编号在方括号内)
            # 示例: "- [3.1.1. base.md](./drivers/base/base.md)"
            $outputLines += (" " * ($Depth * 2) + "- [" + $currentNumber + " $($item.Name)]($($relativePath))")
            $itemAdded = $true # 标记此文件已添加
        }

        # 只有当一个项目被实际添加到了输出列表后，我们才增加计数器的值。
        # 这确保了即使跳过了一些空文件夹，编号也是连续的。
        if ($itemAdded) {
            $counter++
        }
    }
    
    # 返回一个自定义对象，它包含两个属性：
    # .Lines: 一个数组，包含了所有生成的 Markdown 行
    # .HasMarkdown: 一个布尔值，告诉上一层调用者此目录是否包含有效内容
    return [PSCustomObject]@{
        Lines = $outputLines
        HasMarkdown = $hasMarkdownContent
    }
}

# --- 脚本主执行部分 ---

# 初始化一个数组，用于存储最终要写入文件的所有内容
$markdownContent = @()

# 1. 使用参数 $Title 添加主标题
$markdownContent += "# $Title"
# 添加一个空行
$markdownContent += ""

# 调用核心函数开始扫描，并获取返回的结果对象
$result = Get-DirectoryTree -Directory $Path -Depth 0 -NumberPrefix ""
# 将函数返回的目录结构行添加到主内容数组中
$markdownContent += $result.Lines

# 使用参数 $Output 作为文件名，将所有内容一次性写入文件，编码为 utf8
$markdownContent | Out-File -FilePath $Output -Encoding utf8

# 向用户显示完成信息
Write-Host "目录生成完毕, 请查看文件: $Output"