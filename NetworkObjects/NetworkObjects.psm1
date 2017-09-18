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
    <# 
      2do: Check neighbors for backward references
    #>

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

    function findPaths ($nodeMap, $nodePointer = $null, $breadCrumbs = @()) {
      
      # If nodePointer is null (first iteration) get starting node
      if (-not $nodePointer) {
        $nodePointer = $nodeMap[([Array]$nodeMap.keys)[0]]
      }

      # Store a map of which VLANs/network segments are available via which interface
      $segmentMap = @{}
      $nodePointer["segmentMap"] = $segmentMap

      # Work through each interface on the current node
      foreach ($interfaceKey in $nodePointer.interfaces.keys) {

        $interface = $nodePointer.interfaces[$interfaceKey]

        # Record each directly attached segment in the segmentMap
        foreach ($segment in $interface.vlan) {

          $segmentMap[$segment] = $interfaceKey

        }

        # Record each remotely attached segment in the segmentMap
        foreach ($neighborKey in $interface.neighbors.keys) {

          # Make sure we're not looping back to a node we've already visited
          if (-not $breadCrumbs.Contains($neighborKey)) {

            $neighbor = $interface.neighbors[$neighborKey]

            findPaths $nodeMap $neighbor ($breadCrumbs.Add($nodePointer.name))

            # Re-reference all segments available through neighbor
            foreach ($neighborSegmentKey in $neighbor.segmentMap.keys) {
              
              # Make sure we don't already have a reference to a segment reachable through our neighbor
              if (-not ([array]$segmentMap.Keys).Contains($neighborSegmentKey)) {
                # Update the current node's segmentMap to indicate neighbors segments are available through that neighbor
                $segmentMap[$neighborSegmentKey] = $neighborKey
              }

            } #end foreach ($neighborSegmentKey in $neighbor.segmentMap.keys)

          } #end if (-not $breadCrumbs.Contains($neighborKey))

        } #end foreach ($neighborKey in $interface.neighbors.keys)

      } #end foreach ($interfaceKey in $nodePointer.interfaces.keys)

    } #end function findPaths

  } #end begin

  process {
    
    $nodes = @{}

    foreach($file in (Get-ChildItem $Path -Filter "*.json")) {
      
      $jsonNodes = deserializeJsonFile $file
      
      foreach ($nodeKey in $jsonNodes.nodes.keys) {

        $nodes[$nodeKey] = $jsonNodes.nodes[$nodeKey]

      }

    }

    updateNeighborReferences $nodes
    findPaths $nodes

    $Global:results = $nodes
  }
}



Export-ModuleMember -Function 'Build-*'