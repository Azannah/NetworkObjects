<#
  Classes
#>

using namespace System.Net;

class IPAddressExtensions
{
    static [IPAddress] GetBroadcastAddress ([IPAddress] $address, [IPAddress] $subnetMask)
    {
        [byte[]] $ipAdressBytes = $address.GetAddressBytes();
        [byte[]] $subnetMaskBytes = $subnetMask.GetAddressBytes();

        if ($ipAdressBytes.Length -ne $subnetMaskBytes.Length) {
          #throw new ArgumentException("Lengths of IP address and subnet mask do not match.");
        }

        [byte[]] $broadcastAddress = [byte[]]::new($ipAdressBytes.Length);
        for ([int] $i = 0; $i -lt $broadcastAddress.Length; $i++)
        {
            $broadcastAddress[$i] = [byte]($ipAdressBytes[$i] -bor ([Math]::Pow($subnetMaskBytes[$i], 255)));
        }
        return [IPAddress]::new($broadcastAddress);
    }

    static [IPAddress] GetNetworkAddress([IPAddress] $address, [IPAddress] $subnetMask)
    {
        byte[] ipAdressBytes = address.GetAddressBytes();
        byte[] subnetMaskBytes = subnetMask.GetAddressBytes();

        if (ipAdressBytes.Length != subnetMaskBytes.Length)
            throw new ArgumentException("Lengths of IP address and subnet mask do not match.");

        byte[] broadcastAddress = new byte[ipAdressBytes.Length];
        for (int i = 0; i < broadcastAddress.Length; i++)
        {
            broadcastAddress[i] = (byte)(ipAdressBytes[i] & (subnetMaskBytes[i]));
        }
        return new IPAddress(broadcastAddress);
    }

    public static bool IsInSameSubnet(this IPAddress address2, IPAddress address, IPAddress subnetMask)
    {
        IPAddress network1 = address.GetNetworkAddress(subnetMask);
        IPAddress network2 = address2.GetNetworkAddress(subnetMask);

        return network1.Equals(network2);
    }
}

class NodeAccessList {

  [String] $name = $null

  NodeAccessList ([String] $name) {
  
    $this.name = $name

  }

}

class NodeFilter {

  [NodeAccessList] $ingress = $null
  [NodeAccessList] $egress = $null

  NodeAccessList () {
    
  }

  NodeAccessLists ([NodeAccessList] $in, [NodeAccessList] $out) {

    $this.ingress = $in
    $this.egress = $out

  }

}

class NodeInterface {
  
  [String] $name = $null
  [ipaddress]
  [NodeFilter] $accessList = $null
  [NetworkNode[]] $neighbors
  [String] $networkSegment = $null

  NodeInterface ([String] $name, [NodeFilter] $acl, [NetworkNode[]] $neighbors, [String] $networkSegment) {
    
    $this.name = $name

  }

}

class NodeLink {

  []

}

class NetworkNode {
  
  # Properties
  [String] $name = $null
  [NodeInterface[]] $interfaces = @()

  NetworkNode ( [string] $nodeName ) {
    
    $this.name = $nodeName

  }

  [void] addInterface ([NodeInterface] $interface) {

    $this.interfaces.Add($interface)

  }

}

function _deserializeJsonFile ([System.IO.FileInfo] $jsonFile) {
  
  # Instantiate JavaScript Serializer (works with large files better than ConverFrom-Json)
  [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
  $jsonSerializer = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 

  $jsonContents = Get-Content -Path $jsonFile -Raw
	$jsonSerializer.MaxJsonLength = $jsonContents.Length
      
  try {
    $jsonObj = $jsonSerializer.DeserializeObject($jsonContents)
  } catch {
    # 2do: better error handling
    Write-Error "Unable to deserialize specified file: $_"
    break;
  }

  return $jsonObj

}

function _buildNodeFromJson ([System.Management.Automation.PSCustomObject] $jsonNode) {

}

function _buildNodesFromFile ([System.IO.FileInfo] $jsonFile) {
  
  $nodes = @{}

  $jsonNodes = _deserializeJsonFile $jsonFile

  foreach ($nodeKey in $jsonNodes.nodes.keys) {

    $nodes[$nodeKey] = _buildNodeFromJson $jsonNodes.nodes[$nodeKey]

  }

  return $nodes

}

function Get-NetworkNode {

}

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