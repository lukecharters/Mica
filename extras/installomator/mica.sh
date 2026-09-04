mica)
    name="Mica"
    type="pkg"
    downloadURL=$(downloadURLFromGit lukecharters Mica)
    appNewVersion=$(versionFromGit lukecharters Mica)
    expectedTeamID="SFUTCBA5VH"
    blockingProcesses=( "Mica" "mica-cli" )
    ;;