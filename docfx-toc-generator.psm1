function Get-FolderGrabCondition($folderName) {
    $ignoreItemName = ".nodoc"
    $IgnoreFolderDeafultList = ".\.git", ".\_site", ".\obj", ".\src"

    $notInListCondition = (-not $IgnoreFolderDeafultList.Contains($folderName))
    $doesntHaveNoDocFileCondition = (-not [System.IO.File]::Exists([System.IO.Path]::Combine($folderName, $ignoreItemName)))

    return $notInListCondition -and $doesntHaveNoDocFileCondition
}

function Get-SubDocFolders($Path) {
    $dirs = [System.IO.Directory]::GetDirectories($Path, "*", [System.IO.SearchOption]::AllDirectories)

    return $dirs | where { Get-FolderGrabCondition $_ }
}

function Get-RootDocFolder($Path){
    $dirs = [System.IO.Directory]::GetDirectories($Path, "*", [System.IO.SearchOption]::TopDirectoryOnly)

    return $dirs  | where { Get-FolderGrabCondition $_ }
}

function Get-YamlFrontMatter([string]$mdContent, [string]$mdpath) {
    $lines = $mdContent -Split [System.Environment]::NewLine
    if (($lines | where {$_ -eq "---"}).Length -eq 2){
        $firstIndex = $lines.IndexOf("---") + 1
        $secondIndex = $lines[$firstIndex..$lines.Length].IndexOf("---")
        return [string]::Join([System.Environment]::NewLine, $lines[$firstIndex..$secondIndex])
    }
    else{
        Write-Host "Front-matter (Yaml meta-data) for '$mdpath' : NOT FOUND" -ForegroundColor DarkGray
        return "" 
    }
}

function New-TocYaml($folder){
    $mdFiles = [System.IO.Directory]::GetFiles($folder, "*.md", [System.IO.SearchOption]::TopDirectoryOnly) 
    
    $topLevelTocItems = New-Object Collections.Generic.List[Object]
    $mdFiles | % { 
        if([System.IO.Path]::GetFileName($_) -ne "index.md"){
            $tocItem = Get-MarkdownSingleTocItem $_
            $topLevelTocItems.Add($tocItem)
        }
    }

    $subdocTopFolders = Get-RootDocFolder $folder
    $indexFiles = $subdocTopFolders | % { Join-Path $_ "index.md" } | where { [System.IO.File]::Exists($_) }
    
    $indexTocItems = New-Object Collections.Generic.List[Object]
    $indexFiles | % {
        
            $tocItem = Get-MarkdownSingleTocItem $_            
            $dirOfIndex = [System.IO.Path]::GetDirectoryName($_)
            $items = (New-TocYaml $dirOfIndex)
            
            if($null -ne $items -and $null -ne $tocItem -and $items.Length -gt 0){
                $tocItem.Add("items", $items)
            }
            
            $indexTocItems.Add($tocItem)
        
    }

    $result = $topLevelTocItems + $indexTocItems

    return $result
}

function Get-MarkdownSingleTocItem([string]$markdownPath){
    $content = [System.IO.File]::ReadAllText($markdownPath)
    $frontMatter = Get-YamlFrontMatter $content $markdownPath

    if([string]::IsNullOrEmpty($frontMatter)){
        return $null
    }
    $yaml = $frontMatter | ConvertFrom-Yaml

    $noName = $null -eq $yaml.name

    if($noName){
        Write-Host "Front-matter of file '$markdownPath' needs a 'name' tag." -ForegroundColor Red
        return $null
    }

    return @{ "name" = $yaml.name; "href" = $markdownPath }
}

function Build-TocHereRecursive {
    foreach ($docFolder in Get-RootDocFolder .) {
        Write-Host "==== Generating TOC for [$docFolder] ===========================" -ForegroundColor DarkGray
        New-TocYaml $docFolder | ConvertTo-Yaml
        Write-Host "end ===========================" -ForegroundColor DarkGray
    }
}