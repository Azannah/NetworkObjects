<#
	My Function
#>
function Build-NetworkMap {
  [CmdletBinding()]
  Param(
    [Parameter(
      HelpMessage="Path of folder or file containing network node descriptors in json format",
      Mandatory=$true,
      #ParameterSetName="embedded",
      Position=0,
      ValueFromPipeline=$false,
      ValueFromPipelineByPropertyName=$false,
      ValueFromRemainingArguments=$false)]
    #[Alias('FullName')]
    [ValidateScript({Test-Path $_})] #about_Functions_Advanced_Parameters
    [string]
    # The full path and name of the assembly to load (eg., "C:\Program Files\My Application\mylibrary.subnamespace.dll")
    $Path
  )

  begin {
    # json 
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
    $jsonSerializer = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 

    function deserializeJsonFile ($jsonFile) {
      $jsonContents = Get-Content -Path $jsonFile -Raw
	    $jsonSerializer.MaxJsonLength = $jsonContents.Length
      
      try {
        $jsonObj = $jsonSerializer.DeserializeObject($jsonContents)
      } catch {
        Write-Error "Unable to deserialize specified file: $_"
        break;
      }

      return $jsonObj

    }

    function updateNeighborReferences ($nodes) {

      foreach ($nodeKey in $nodes.keys) {

        foreach ($interfaceKey in $nodes[$nodeKey].interfaces.keys) {
          
          $validNeighbors = @{}
          $invalidNeighbors = @()

          foreach ($neighborKey in $nodes[$nodeKey].interfaces[$interfaceKey].neighbors) {
            if ($nodes.ContainsKey($neighborKey)) {
              $validNeighbors[$neighborKey] = $nodes[$neighborKey]
            } else {
              $invalidNeighbors += $neighborKey
              Write-Error "Interface $interfaceKey on $nodeKey : $neighborKey is not a valid neighbor"
            }

          }

          $nodes[$nodeKey].interfaces[$interfaceKey].neighbors = $validNeighbors
          $nodes[$nodeKey].interfaces[$interfaceKey]["invalidNeighbors"] = $invalidNeighbors

        }

      }

    }

    function findPaths ($nodeMap, $nodePointer, $breadCrumbs = $null) {

    }

  }

  process {
    
    $nodes = @{}

    foreach($file in (Get-ChildItem $Path -Filter "*.json")) {
      
      $jsonNodes = deserializeJsonFile $file
      
      foreach ($nodeKey in $jsonNodes.nodes.keys) {

        $nodes[$nodeKey] = $jsonNodes.nodes[$nodeKey]

      }

    }

    updateNeighborReferences $nodes

    $Global:results = $nodes
  }
}



Export-ModuleMember -Function 'Build-*'