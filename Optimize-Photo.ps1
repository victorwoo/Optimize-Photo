# TODO
# 1. 删除重复文件
# 2. 删除非 HDR 文件
# 3. 旋转照片
# 4. 输出时遇到重名文件：1. 比较 2. 改名。

#$inputDir = 'E:\Photo\optimize'
#cd D:\sync\vichamp\Optimize-Photo

$DebugPreference = "Continue"
. .\get-exif.ps1
. .\Get-Image.ps1

function Get-FileType ($ext) {
    if ('.avi', '.mov', '.3gp' -contains $ext) {
        return 'video'
    }

    if ('.jpg', '.png', '.bmp' -contains $ext) {
        return 'photo'
    }

    return 'unknown'
}

function Rename-Photo ($file) {
    # http://archive.msdn.microsoft.com/PSImage
    #Import-Module Image

    $file = $_
    $fileName = $_.Name
    $baseName = $_.BaseName
    $extension = $_.Extension
    if ($extension -ne $null) { $extension = $extension.ToLower() }

    # Write-Debug "正在处理 $fileName"

    $matched = $false
        
    # 从 Exif 信息提取时间
    # 2010:11:07 14:42:21
    $exifIDDateTimeTaken = Get-ExifItem -ExifID 36867 -image (Get-Image $_.FullName)
    if ($exifIDDateTimeTaken -ne $null) { $matched = $exifIDDateTimeTaken -cmatch '^(?<YEAR>\d{4}):(?<MONTH>\d{2}):(?<DAY>\d{2}) (?<HOUR>\d{2}):(?<MINUTE>\d{2}):(?<SECOND>\d{2})$' }

    # 以下从文件名提取时间

    # Android 自带相机照片
    # 2010-07-21 13.25.54.jpg
    # 2010-08-08 06.32.34[0].jpgz
    if (!$matched) { $matched = $baseName -cmatch '^(?<YEAR>\d{4})-(?<MONTH>\d{2})-(?<DAY>\d{2}) (?<HOUR>\d{2})\.(?<MINUTE>\d{2})\.(?<SECOND>\d{2})(?:\[\d+\])?\s*(?<REST>.*)$' }

    # Camera 360 相机
    # C360_2010-09-30 10-55-52.jpg
    # C360_2010-09-30 10-56-34.Share.jpg
    # C360_2010-10-02 20-20-50-1.jpg
    if (!$matched) { $matched = $baseName -cmatch '^C360_(?<YEAR>\d{4})-(?<MONTH>\d{2})-(?<DAY>\d{2}) (?<HOUR>\d{2})-(?<MINUTE>\d{2})-(?<SECOND>\d{2})\s*(?<REST>.*)$' }

    # 疑似 Android 自带相机视频
    # video-2010-08-27-21-53-27.3gp
    if (!$matched) { $matched = $baseName -cmatch '^video-(?<YEAR>\d{4})-(?<MONTH>\d{2})-(?<DAY>\d{2})-(?<HOUR>\d{2})-(?<MINUTE>\d{2})-(?<SECOND>\d{2})\s*(?<REST>.*)$' }
        
    # 百度云同步盘
    # 2013-09-11 234206(1).jpg
    # 2013-09-11 234206.jpg
    # 2013-08-10 192913.mov
    if (!$matched) { $matched = $baseName -cmatch '^(?<YEAR>\d{4})-(?<MONTH>\d{2})-(?<DAY>\d{2}) (?<HOUR>\d{2})(?<MINUTE>\d{2})(?<SECOND>\d{2})\s*(?<REST>.*)$' }

    # 微云
    # 20131113101746588.JPG
    # 20131113101746588(0).JPG
    # 20131113101746797.JPG
    if (!$matched) { $matched = $baseName -cmatch '^(?<YEAR>\d{4})(?<MONTH>\d{2})(?<DAY>\d{2})(?<HOUR>\d{2})(?<MINUTE>\d{2})(?<SECOND>\d{2})(?<MILLISECOND>\d{3})\s*(?<REST>.*)$' }

    # 从 Exif 或者文件名中取到时间
    if ($matched) {
        [int]$year = $Matches['YEAR']
        [int]$month = $Matches['MONTH']
        [int]$day = $Matches['DAY']
        [int]$hour = $Matches['HOUR']
        [int]$minute = $Matches['MINUTE']
        [int]$second = $Matches['SECOND']
        [int]$millisecond = $Matches['MILLISECOND']
        [string]$rest = $Matches['REST']
    } else {
    <#
        # iPhone照片、视频；佳能相机照片；扫描仪
        # IMG_1050.JPG
        if (!$matched) { $matched = $baseName -cmatch '^IMG_\d+$' }

        # 佳能相机视频
        # MVI_0037.AVI
        if (!$matched) { $matched = $baseName -cmatch '^MVI_\d+$' }
    #>
        if ($file.CreationTime -ge $file.LastWriteTime) {
            $time = $file.LastWriteTime
        } else {
            $time = $file.CreationTime
        }

        [int]$year = $time.Year
        [int]$month = $time.Month
        [int]$day = $time.Day
        [int]$hour = $time.Hour
        [int]$minute = $time.Minute
        [int]$second = $time.Second
        [int]$millisecond = $time.Millisecond
        [string]$rest = ''
    }

    # 根据以上信息生成新的文件名
    $newBaseName = "{0:d4}-{1:d2}-{2:d2} {3:d2}.{4:d2}.{5:d2}" -f $year, $month, $day, $hour, $minute, $second
    if ($rest) {
        $rest = $rest.Trim()
        $rest = $rest.TrimStart('-')
        $rest = $rest.TrimStart('(')
        $rest = $rest.TrimEnd(')')
        $rest = $rest.TrimStart('[')
        $rest = $rest.TrimEnd(']')
        if ($rest -cnotmatch '\d+') {
            $newBaseName = "{0} [1]" -f $newBaseName, $rest
        }
    }

    $newFileName = "{0}{1}" -f $newBaseName, $extension
        
    $fileType = Get-FileType $extension
    <#
    $folder = "$fileType.bydate"
    if (!(Test-Path $folder)) {
        md $folder | Out-Null
    }
    #>
    
    $folder = $file.DirectoryName
    $newPath = Join-Path $folder "$newFileName"
    $i = 1
    while ($true) {
        if ($file.FullName -ieq $newPath) {
            # 新文件 = 原始文件，什么也不做（无需移动文件）
            return
        }

        if (Test-Path $newPath) {
            # 换名
            $newFileName = "$newBaseName ($i)$extension"
            $newPath = Join-Path $folder "$newFileName"
            $i++
        } else {
            break
        }
    }

    echo "$($file.FullName) -> $newPath"
    move -LiteralPath $_.FullName "$newPath" #-WhatIf
}

del .picasa.ini, _cache, Thumbs.db -Recurse -ErrorAction SilentlyContinue

dir -Recurse *.jpg, *.png, *.avi, *.mov, *.3gp | 
    where { -not $_.Directory.Name.Contains('bydate') -and -not $_.Directory.Name.Contains('unknown') } | foreach {
    Rename-Photo $_
}

Get-ChildItem -recurse | Where {$_.PSIsContainer -and `
@(Get-ChildItem -Lit $_.Fullname -r | Where {!$_.PSIsContainer}).Length -eq 0} |
Remove-Item -recurse #-whatif

dir *.jpg, *.png, *.avi, *.mov, *.3gp | % {
    $baseName = $_.BaseName
    $matched = $baseName -cmatch '^(?<YEAR>\d{4})-(?<MONTH>\d{2})-(?<DAY>\d{2}) (?<HOUR>\d{2})\.(?<MINUTE>\d{2})\.(?<SECOND>\d{2})(?:\[\d+\])?\s*(?<REST>.*)$'

    if ($matched) {
        [int]$year = $Matches['YEAR']
        [int]$month = $Matches['MONTH']
        [int]$q = [math]::Floor(($month-1)/4)+1
    }
    $newFolder = "$year-Q$q"
    if (!(Test-Path $newFolder)) {
        md $newFolder | Out-Null
    }
    move -LiteralPath $_.FullName (Join-Path $newFolder $_.Name) #-WhatIf
}