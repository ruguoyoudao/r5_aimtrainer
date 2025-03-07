///////////////////////////////////////////////////////
// ███████ ██       ██████  ██     ██     ███████ ████████  █████  ████████ ███████
// ██      ██      ██    ██ ██     ██     ██         ██    ██   ██    ██    ██
// █████   ██      ██    ██ ██  █  ██     ███████    ██    ███████    ██    █████
// ██      ██      ██    ██ ██ ███ ██          ██    ██    ██   ██    ██    ██
// ██      ███████  ██████   ███ ███      ███████    ██    ██   ██    ██    ███████
///////////////////////////////////////////////////////
// Credits:
// CaféDeColombiaFPS (Retículo Endoplasmático#5955) -- owner/main dev
// michae\l/#1125 -- initial help
// AyeZee#6969 -- tdm/ffa dropships and droppods
// Zer0Bytes#4428 -- rewrite
// everyone else -- advice


global function _CustomTDM_Init
global function _RegisterLocation
global function CharSelect
global function CreateAnimatedLegend
global function Message
global function shuffleArray
global bool isBrightWaterByZer0 = false
global function WpnAutoReloadOnKill
global function GetTDMState
global function SetTdmStateToNextRound
global function SetTdmStateToInProgress
global function SetFallTriggersStatus
global function ResetDeathPlayersCounterForFirstBloodAnnouncer
global function CreateShipRoomFallTriggers

global function ClientCommand_ClientMsg
global function	ClientCommand_DispayChatHistory
global function	ClientCommand_RebalanceTeams
global function	ClientCommand_FlowstateKick
global function	ClientCommand_ShowLatency

const string WHITE_SHIELD = "armor_pickup_lv1"
const string BLUE_SHIELD = "armor_pickup_lv2"
const string PURPLE_SHIELD = "armor_pickup_lv3"

#if SERVER
global function GiveFlowstateOvershield
#endif

bool plsTripleAudio = false;
table playersInfo
const int chatLines = 3
int currentChatLine = 0
string currentChat = ""

enum eTDMState
{
	IN_PROGRESS = 0
	NEXT_ROUND_NOW = 1
}

struct {
	string scriptversion = "v3.1"
    int tdmState = eTDMState.IN_PROGRESS
    int nextMapIndex = 0
	bool mapIndexChanged = true
	array<entity> playerSpawnedProps
	array<ItemFlavor> characters
	float lastTimeChatUsage
	float lastKillTimer
	entity lastKiller
	int SameKillerStoredKills=0
	array<string> whitelistedWeapons
	array<LocationSettings> locationSettings
    LocationSettings& selectedLocation
	array<vector> thisroundDroppodSpawns
    entity ringBoundary
	entity previousChampion
	entity previousChallenger
	int deathPlayersCounter=0
	int maxPlayers
	int maxTeams

	array<string> mAdmins
	array<string> mChatBanned

	int randomprimary
    int randomsecondary
    int randomult
    int randomtac

    entity supercooldropship
	bool isshipalive = false
	array<LocationSettings> droplocationSettings
    LocationSettings& dropselectedLocation

	bool FallTriggersEnabled = false
	bool mapSkyToggle = false
} file

struct PlayerInfo
{
	string name
	int team
	int score
	int deaths
	float kd
	int damage
	int lastLatency
}

// ██████   █████  ███████ ███████     ███████ ██    ██ ███    ██  ██████ ████████ ██  ██████  ███    ██ ███████
// ██   ██ ██   ██ ██      ██          ██      ██    ██ ████   ██ ██         ██    ██ ██    ██ ████   ██ ██
// ██████  ███████ ███████ █████       █████   ██    ██ ██ ██  ██ ██         ██    ██ ██    ██ ██ ██  ██ ███████
// ██   ██ ██   ██      ██ ██          ██      ██    ██ ██  ██ ██ ██         ██    ██ ██    ██ ██  ██ ██      ██
// ██████  ██   ██ ███████ ███████     ██       ██████  ██   ████  ██████    ██    ██  ██████  ██   ████ ███████

void function _CustomTDM_Init()
{
	printt("[Flowstate] -> _CustomTDM_Init")
	SurvivalFreefall_Init() //Enables freefall/skydive
	PrecacheCustomMapsProps()

    __InitAdmins()

    AddCallback_EntitiesDidLoad( __OnEntitiesDidLoad )

    AddCallback_OnClientConnected( void function(entity player) {
        if(FlowState_PROPHUNT())
            thread _OnPlayerConnectedPROPHUNT(player)
        else if (FlowState_SURF())
            thread _OnPlayerConnectedSURF(player)
        else thread _OnPlayerConnected(player)

        UpdatePlayerCounts()
    })

    AddSpawnCallback( "prop_survival", DissolveItem )

    AddCallback_OnPlayerKilled(void function(entity victim, entity attacker, var damageInfo) {
        if(FlowState_PROPHUNT())
            thread _OnPlayerDiedPROPHUNT(victim, attacker, damageInfo)
        else if (FlowState_SURF())
            thread _OnPlayerDiedSURF(victim, attacker, damageInfo)
        else thread _OnPlayerDied(victim, attacker, damageInfo)
    })

	if(FlowState_PROPHUNT()){
		AddClientCommandCallback("next_round", ClientCommand_NextRoundPROPHUNT)
		AddClientCommandCallback("scoreboard", ClientCommand_ScoreboardPROPHUNT)
	} else if (FlowState_SURF()){
		AddClientCommandCallback("spectate", ClientCommand_SpectateSURF) //todo fix this
		AddClientCommandCallback("next_round", ClientCommand_NextRoundSURF)
	} else{
		AddClientCommandCallback("scoreboard", ClientCommand_Scoreboard)
		AddClientCommandCallback("spectate", ClientCommand_SpectateEnemies)
		AddClientCommandCallback("teambal", ClientCommand_RebalanceTeams)
		AddClientCommandCallback("circlenow", ClientCommand_CircleNow)
		AddClientCommandCallback("god", ClientCommand_God)
		AddClientCommandCallback("ungod", ClientCommand_UnGod)
		AddClientCommandCallback("next_round", ClientCommand_NextRound)
		AddClientCommandCallback("tgive", ClientCommand_GiveWeapon)
	}
	if(FlowState_AllChat() && !FlowState_SURF()){
		AddClientCommandCallback("say", ClientCommand_ClientMsg)
		AddClientCommandCallback("sayhistory", ClientCommand_DispayChatHistory)
		AddClientCommandCallback("sayban", ClientCommand_ChatBan)
		AddClientCommandCallback("sayunban", ClientCommand_ChatUnBan)
		AddClientCommandCallback("saylist", ClientCommand_ChatBanList)

	}
	AddClientCommandCallback("latency", ClientCommand_ShowLatency)
	AddClientCommandCallback("flowstatekick", ClientCommand_FlowstateKick)
	AddClientCommandCallback("adminsay", ClientCommand_AdminMsg)
	AddClientCommandCallback("commands", ClientCommand_Help)
	
	for(int i = 0; GetCurrentPlaylistVarString("whitelisted_weapon_" + i.tostring(), "~~none~~") != "~~none~~"; i++)
	{
		file.whitelistedWeapons.append(GetCurrentPlaylistVarString("whitelisted_weapon_" + i.tostring(), "~~none~~"))
	}

	if(FlowState_PROPHUNT()){
		thread RunPROPHUNT()
	} else if(FlowState_SURF()){
		thread RunSURF()
	}else {
		thread RunTDM()}
}

void function __OnEntitiesDidLoad()
{
	switch(GetMapName())
    {
    	case "mp_rr_canyonlands_staging": SpawnMapPropsFR(); break
    	case "mp_rr_arena_composite":
		{
			array<entity> badMovers = GetEntArrayByClass_Expensive( "script_mover" )
			foreach(mover in badMovers)
				if( IsValid(mover) ) mover.Destroy()
			break
		}
    }
}

void function _RegisterLocation(LocationSettings locationSettings)
{
    file.locationSettings.append(locationSettings)
    file.droplocationSettings.append(locationSettings)
}

LocPair function _GetVotingLocation()
{
    switch(GetMapName())
    {
		case "mp_rr_aqueduct_night":
        case "mp_rr_aqueduct":
             return NewLocPair(<4885, -4076, 400>, <0, -157, 0>)
        case "mp_rr_canyonlands_staging":
             return NewLocPair(<26794, -6241, -27479>, <0, 0, 0>)
        case "mp_rr_canyonlands_64k_x_64k":
			return NewLocPair(<-19459, 2127, 18404>, <0, 180, 0>)
		case "mp_rr_ashs_redemption":
            return NewLocPair(<-20917, 5852, -26741>, <0, -90, 0>)
        case "mp_rr_canyonlands_mu1":
        case "mp_rr_canyonlands_mu1_night":
		    return NewLocPair(<-19459, 2127, 18404>, <0, 180, 0>)
        case "mp_rr_desertlands_64k_x_64k":
        case "mp_rr_desertlands_64k_x_64k_nx":
			return NewLocPair(<-19459, 2127, 6404>, <0, 180, 0>)
        case "mp_rr_arena_composite":
                return NewLocPair(<0, 4780, 220>, <0, -90, 0>)
        default:
            Assert(false, "No voting location for the map!")
    }
    unreachable
}

void function _OnPropDynamicSpawned(entity prop)
{
    file.playerSpawnedProps.append(prop)
}

int function GetTDMState(){
	return file.tdmState
}

void function SetTdmStateToNextRound(){
	file.tdmState = eTDMState.NEXT_ROUND_NOW
}

void function SetTdmStateToInProgress(){
	file.tdmState = eTDMState.IN_PROGRESS
}

void function SetFallTriggersStatus(bool status){
	file.FallTriggersEnabled = status
}

void function ResetDeathPlayersCounterForFirstBloodAnnouncer(){
	file.deathPlayersCounter=0
}
LocPair function _GetAppropriateSpawnLocation(entity player)
{
    bool needSelectRespawn = true
    if(!IsValid(player))
        needSelectRespawn = false

    LocPair selectedSpawn = _GetVotingLocation()

	switch(GetGameState())
    {
        case eGameState.MapVoting: selectedSpawn = _GetVotingLocation(); break
        case eGameState.Playing:
            float maxDistToEnemy = 0
            foreach(spawn in file.selectedLocation.spawns)
            {
	    		if (needSelectRespawn)
                {
                    vector enemyOrigin = GetClosestEnemyToOrigin(spawn.origin, player.GetTeam())
                    float distToEnemy = Distance(spawn.origin, enemyOrigin)

                    if(distToEnemy > maxDistToEnemy)
                    {
                        maxDistToEnemy = distToEnemy
                        selectedSpawn = spawn
                    }
	    		} else selectedSpawn = spawn
            }
        break
    }
    return selectedSpawn
}

vector function GetClosestEnemyToOrigin(vector origin, int ourTeam)
{
    float minDist = -1
    vector enemyOrigin = <0, 0, 0>

    foreach(player in GetPlayerArray_Alive())
    {
        if(player.GetTeam() == ourTeam) continue

        float dist = Distance(player.GetOrigin(), origin)
        if(dist < minDist || minDist < 0)
            minDist = dist ; enemyOrigin = player.GetOrigin()
    }

    return enemyOrigin
}

void function DestroyPlayerProps()
{
    foreach(prop in file.playerSpawnedProps)
    {
        if(IsValid(prop))
            prop.Destroy()
    }
    file.playerSpawnedProps.clear()
	WaitFrame()
}

void function DissolveItem(entity prop)
{
	thread (void function( entity prop) {
		wait 4
	    if(prop == null || !IsValid(prop))
	    	return

	    entity par = prop.GetParent()
	    if(par && par.GetClassName() == "prop_physics" && IsValid(prop))
	    	prop.Dissolve(ENTITY_DISSOLVE_CORE, <0,0,0>, 200)
	}) ( prop )
}

void function _OnPlayerConnected(entity player)
{
    if(!IsValid(player)) return

	if(FlowState_ForceCharacter()){
		player.SetPlayerNetBool( "hasLockedInCharacter", true)
		CharSelect(player)
	}

	if(GetMapName() == "mp_rr_aqueduct")
	    if(IsValid(player)) {
	    	CreatePanelText( player, "Flowstate", "", <3705.10547, -4487.96484, 470.03302>, <0, 190, 0>, false, 2 )
	    	CreatePanelText( player, "Flowstate", "", <1111.36584, -5447.26221, 655.479858>, <0, -90, 0>, false, 2 )
	    }

    GivePassive(player, ePassives.PAS_PILOT_BLOOD)
	SetPlayerSettings(player, TDM_PLAYER_SETTINGS)

	if(FlowState_RandomGunsEverydie())
	    Message(player, "FLOWSTATE: FIESTA", "Type 'commands' in console to see the available console commands. ", 10)
	else if (FlowState_Gungame())
	    Message(player, "FLOWSTATE: GUNGAME", "Type 'commands' in console to see the available console commands. ", 10)
	else
	    Message(player, "FLOWSTATE: FFA/TDM", "Type 'commands' in console to see the available console commands. ", 10)

	if(IsValid(player))
	{
		switch(GetGameState())
		{
			case eGameState.MapVoting:
			    {
			    	if(!IsAlive(player))
			    	{
			    		_HandleRespawn(player)
			    		ClearInvincible(player)
			    	}

			    	player.SetThirdPersonShoulderModeOn()

			    	if(FlowState_RandomGunsEverydie())
			    		UpgradeShields(player, true)

			    	if(FlowState_Gungame())
			    		KillStreakAnnouncer(player, true)

			    	player.UnforceStand()
			    	player.FreezeControlsOnServer()
			    }
			break
			case eGameState.WaitingForPlayers:
				{
					_HandleRespawn(player)
					ClearInvincible(player)
					player.UnfreezeControlsOnServer()
				}
			break
			case eGameState.Playing:
				{
					player.UnfreezeControlsOnServer()

					_HandleRespawn(player)

                    array<string> InValidMaps = [
						"mp_rr_canyonlands_staging",
						"Skill trainer By Colombia",
						"Custom map by Biscutz",
						"White Forest By Zer0Bytes",
						"Brightwater By Zer0bytes"
					]

					bool DropPodOnSpawn = GetCurrentPlaylistVarBool("flowstateDroppodsOnPlayerConnected", false )
					bool IsStaging = InValidMaps.find( GetMapName() ) != -1
					bool IsMapValid = InValidMaps.find(file.selectedLocation.name) != -1
					if(file.tdmState == eTDMState.NEXT_ROUND_NOW || DropPodOnSpawn || IsStaging || IsMapValid )
						_HandleRespawn(player)
					else
					{
						player.p.isPlayerSpawningInDroppod = true
						thread AirDropFireteam( file.thisroundDroppodSpawns[RandomIntRangeInclusive(0, file.thisroundDroppodSpawns.len()-1)] + <0,0,15000>, <0,180,0>, "idle", 0, "droppod_fireteam", player )
						_HandleRespawn(player, true)
						player.SetAngles( <0,180,0> )
					}

					ClearInvincible(player)
					if(FlowState_RandomGunsEverydie())
						UpgradeShields(player, true)

					if(FlowState_Gungame())
						KillStreakAnnouncer(player, true)
				}
				break
			default:
				break
		}
	}

	thread __HighPingCheck( player )
}

void function __HighPingCheck(entity player)
{
	wait 12
    if(!IsValid(player)) return

	if ( FlowState_KickHighPingPlayer() && (int(player.GetLatency()* 1000) - 40) > FlowState_MaxPingAllowed() )
	{
		player.FreezeControlsOnServer() ; player.ForceStand() ; HolsterAndDisableWeapons( player )

		Message(player, "FLOWSTATE KICK", "Your ping is too high: " + (int(player.GetLatency()* 1000) - 40), 3)

		wait 3

		#if SERVER
		printl("[Flowstate] -> Kicking " + player.GetPlayerName() + " -> [High Ping]")
		ServerCommand( "kick " + player.GetPlayerName() )
		#endif

		UpdatePlayerCounts()
	} else if(GameRules_GetGameMode() == "custom_tdm"){
		Message(player, "FLOWSTATE",
		"    Enjoy your stay, " + player.GetPlayerName() +
		" Your latency: " + (int(player.GetLatency()* 1000) - 40) + " ms."
		, 5)
	}
}

void function doubletriplekillaudio(entity victim, entity attacker)
{
	entity champion = file.previousChampion
	entity challenger = file.previousChallenger
	entity killeader = GetBestPlayer()
	float doubleKillTime = 5.0
	float tripleKillTime = 8.0

	if(!IsValid(attacker)) return

	bool ReqCheck = attacker == file.lastKiller && attacker == killeader
	if(ReqCheck)
	{
		if(!plsTripleAudio)
			attacker.p.downedEnemyAtOneTime = 2
		else if (plsTripleAudio)
			attacker.p.downedEnemyAtOneTime = 3
	}

	if((Time() - attacker.p.lastKillTimer) < doubleKillTime && ReqCheck && attacker.p.downedEnemyAtOneTime == 2){
		foreach (player in GetPlayerArray())
		    thread EmitSoundOnEntityOnlyToPlayer( player, player, "diag_ap_aiNotify_killLeaderDoubleKill" )

		if(FlowState_ChosenCharacter() == 8)
			thread EmitSoundOnEntityOnlyToPlayer( attacker, attacker, "diag_mp_wraith_bc_iDownedMultiple_1p" )
		plsTripleAudio = true;
	}

	if((Time() - attacker.p.lastKillTimer) < tripleKillTime && ReqCheck && attacker.p.downedEnemyAtOneTime == 3){
		attacker.p.downedEnemyAtOneTime = 0
		wait 1
		foreach (player in GetPlayerArray())
		    thread EmitSoundOnEntityOnlyToPlayer( player, player, "diag_ap_aiNotify_killLeaderTripleKill" )
		plsTripleAudio = false;
	}
}

void function _OnPlayerDied(entity victim, entity attacker, var damageInfo)
{
	if (FlowState_RandomGunsEverydie() && FlowState_FIESTADeathboxes())
		CreateFlowStateDeathBoxForPlayer(victim, attacker, damageInfo)

	switch(GetGameState())
    {
        case eGameState.Playing:
            // Víctim
            void functionref() victimHandleFunc = void function() : (victim, attacker, damageInfo) {
	    		wait 1
	    		if(!IsValid(victim)) return

	    		if(file.tdmState != eTDMState.NEXT_ROUND_NOW && IsValid(victim) && IsValid(attacker) && Spectator_GetReplayIsEnabled() && ShouldSetObserverTarget( attacker )){
	    			victim.SetObserverTarget( attacker )
	    			victim.SetSpecReplayDelay( 4 )
	    			victim.StartObserverMode( OBS_MODE_IN_EYE )
	    			Remote_CallFunction_NonReplay(victim, "ServerCallback_KillReplayHud_Activate")
	    		}

	    		int invscore = victim.GetPlayerGameStat( PGS_DEATHS )
	    		invscore++
	    		victim.SetPlayerGameStat( PGS_DEATHS, invscore)

	    		//Add a death to the victim
	    		int invscore2 = victim.GetPlayerNetInt( "assists" )
	    		invscore2++
	    		victim.SetPlayerNetInt( "assists", invscore2 )

	    		if(FlowState_RandomGunsEverydie())
	    		    UpgradeShields(victim, true)

	    		if(FlowState_Gungame())
	    		    KillStreakAnnouncer(victim, true)

	    		if(file.tdmState != eTDMState.NEXT_ROUND_NOW)
	    		    wait 8

	    		_HandleRespawn( victim )
	    		ClearInvincible(victim)
	    	}

            // Attacker
            void functionref() attackerHandleFunc = void function() : (victim, attacker, damageInfo)
	    	{
	    		if(IsValid(attacker) && attacker.IsPlayer() && IsAlive(attacker) && attacker != victim)
                {
	    			//Heal
	    			if(FlowState_RandomGunsEverydie() && FlowState_FIESTAShieldsStreak())
					{
	    			    PlayerRestoreHPFIESTA(attacker, 100)
	    			    UpgradeShields(attacker, false)
	    			} else PlayerRestoreHP(attacker, 100, Equipment_GetDefaultShieldHP())

	    			if(FlowState_KillshotEnabled())
					{
	    			    DamageInfo_AddCustomDamageType( damageInfo, DF_KILLSHOT )
	    			    thread EmitSoundOnEntityOnlyToPlayer( attacker, attacker, "flesh_bulletimpact_downedshot_1p_vs_3p" )
	    			}

	    			if(FlowState_Gungame())
	    			{
	    			    GiveGungameWeapon(attacker)
	    			    KillStreakAnnouncer(attacker, false)
	    			}

	    			WpnAutoReloadOnKill(attacker)
	    			GameRules_SetTeamScore(attacker.GetTeam(), GameRules_GetTeamScore(attacker.GetTeam()) + 1)
	    			if(attacker.IsPlayer()) attacker.p.lastKillTimer = Time()
	    		}
            }
	    	thread victimHandleFunc()
            thread attackerHandleFunc()
        break
        default:
	    	_HandleRespawn(victim)
	    break
    }

	file.deathPlayersCounter++
	if(file.deathPlayersCounter == 1 )
	{
		foreach (player in GetPlayerArray())
			thread EmitSoundOnEntityExceptToPlayer( player, player, "diag_ap_aiNotify_diedFirst" )
	}

	if(attacker.IsPlayer())
	    file.lastKiller = attacker
	UpdatePlayerCounts()
}


void function _HandleRespawn(entity player, bool isDroppodSpawn = false)
{
    if(!IsValid(player)) return

	if( player.IsObserver())
    {
		player.StopObserverMode()
        Remote_CallFunction_NonReplay(player, "ServerCallback_KillReplayHud_Deactivate")
    }

	if(IsValid( player ) && !IsAlive(player))
    {
        if(Equipment_GetRespawnKitEnabled() && !FlowState_Gungame())
        {
			DecideRespawnPlayer(player, true)
            player.TakeOffhandWeapon(OFFHAND_TACTICAL)
            player.TakeOffhandWeapon(OFFHAND_ULTIMATE)
            array<StoredWeapon> weapons = [
                Equipment_GetRespawnKit_PrimaryWeapon(),
                Equipment_GetRespawnKit_SecondaryWeapon(),
                Equipment_GetRespawnKit_Tactical(),
                Equipment_GetRespawnKit_Ultimate()
            ]
            foreach (storedWeapon in weapons)
            {
                if ( !storedWeapon.name.len() ) continue
                if( storedWeapon.weaponType == eStoredWeaponType.main)
                    player.GiveWeapon( storedWeapon.name, storedWeapon.inventoryIndex, storedWeapon.mods )
                else
                    player.GiveOffhandWeapon( storedWeapon.name, storedWeapon.inventoryIndex, storedWeapon.mods )
            }
		}
        else
        {
            if(!player.p.storedWeapons.len())
            {
				DecideRespawnPlayer(player, true)
				array<StoredWeapon> weapons = [
					Equipment_GetRespawnKit_PrimaryWeapon(),
					Equipment_GetRespawnKit_SecondaryWeapon()]
				foreach (storedWeapon in weapons)
					player.GiveWeapon( storedWeapon.name, storedWeapon.inventoryIndex, storedWeapon.mods )
			}
            else
            {
				DecideRespawnPlayer(player, false)
                GiveWeaponsFromStoredArray(player, player.p.storedWeapons)
            }
        }
    }

	if( IsValid( player ) && IsAlive(player))
	{
		if(!isDroppodSpawn)
		    TpPlayerToSpawnPoint(player)

		player.UnfreezeControlsOnServer()

		if(FlowState_RandomGunsEverydie() && FlowState_FIESTAShieldsStreak())
		{
			PlayerRestoreShieldsFIESTA(player, player.GetShieldHealthMax())
			PlayerRestoreHPFIESTA(player, 100)
		} else PlayerRestoreHP(player, 100, Equipment_GetDefaultShieldHP())

		player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_2 )
		player.TakeOffhandWeapon( OFFHAND_MELEE )
		player.TakeOffhandWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_2 )
		player.GiveWeapon( "mp_weapon_melee_survival", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
		player.GiveOffhandWeapon( "melee_data_knife", OFFHAND_MELEE, [] )
	}

	if (FlowState_RandomGuns() && !FlowState_Gungame() && IsValid( player ))
    {
		try{
		    player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
            player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_1 )
		    player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_2 )

		GiveRandomPrimaryWeapon(player)
		GiveRandomSecondaryWeapon(player)

            player.GiveWeapon( "mp_weapon_melee_survival", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
            player.GiveOffhandWeapon( "melee_data_knife", OFFHAND_MELEE, [] )
		} catch (e) {}
    } else if(FlowState_RandomGunsMetagame() && !FlowState_Gungame() && IsValid( player ))
	{
		try{
		    player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
            player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_1 )
		    player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_2 )
			GiveRandomPrimaryWeaponMetagame(player)
			GiveRandomSecondaryWeaponMetagame(player)

            player.GiveWeapon( "mp_weapon_melee_survival", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
            player.GiveOffhandWeapon( "melee_data_knife", OFFHAND_MELEE, [] )
		} catch (e) {}
	}

	if( IsValid( player ) || FlowState_GungameRandomAbilities() && IsValid( player ))
	{
		if(FlowState_RandomTactical())
		{
			player.TakeOffhandWeapon(OFFHAND_TACTICAL)
			GiveRandomTac(player)
		}

		if(FlowState_RandomUltimate())
		{
			player.TakeOffhandWeapon(OFFHAND_ULTIMATE)
			GiveRandomUlt(player)
		}

	}

	if(FlowState_RandomGunsEverydie() && !FlowState_Gungame() && IsValid( player )) //fiesta
    {
		TakeAllWeapons(player)
        GiveRandomPrimaryWeapon(player)
        GiveRandomSecondaryWeapon( player)
        GiveRandomTac(player)
        GiveRandomUlt(player)
        player.GiveWeapon( "mp_weapon_melee_survival", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
        player.GiveOffhandWeapon( "melee_data_knife", OFFHAND_MELEE, [] )
    }
	if(FlowState_Gungame() && IsValid( player ))
		GiveGungameWeapon(player)

	thread WpnPulloutOnRespawn(player)
}

void function TpPlayerToSpawnPoint(entity player)
{
	LocPair loc = _GetAppropriateSpawnLocation(player)
    player.SetOrigin(loc.origin) ; player.SetAngles(loc.angles)
}

void function GrantSpawnImmunity(entity player, float duration)
{
	if(!IsValid(player)) return

    MakeInvincible(player)
	wait duration

	if(IsValid(player))
		ClearInvincible(player)
}

void function WpnAutoReloadOnKill( entity player )
{

	entity primary = player.GetLatestPrimaryWeapon( eActiveInventorySlot.mainHand )
	entity sec = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 )

	if (primary == sec) {
		sec = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
	}

	if (FlowState_AutoreloadOnKillPrimary() && IsValid(primary) && primary.GetWeaponClassName() != "mp_weapon_melee_survival") {
		if(primary.UsesClipsForAmmo())
			primary.SetWeaponPrimaryClipCount(primary.GetWeaponPrimaryClipCountMax())
		else
		{
			int ammoType = primary.GetWeaponAmmoPoolType()
			player.AmmoPool_SetCapacity( 999 )
			player.AmmoPool_SetCount( ammoType, 999)
		}
	}

	if (FlowState_AutoreloadOnKillSecondary() && IsValid(sec)) {
		if(sec.UsesClipsForAmmo())
			sec.SetWeaponPrimaryClipCount(sec.GetWeaponPrimaryClipCountMax())
		else
		{
			int ammoType = sec.GetWeaponAmmoPoolType()
			player.AmmoPool_SetCapacity( 999 )
			player.AmmoPool_SetCount( ammoType, 999)
		}
	}
}

void function WpnPulloutOnRespawn(entity player)
{
	if( IsValid( player ) && IsAlive(player))
    {
	    if(IsValid( player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 ) ))
	    	player.SetActiveWeaponBySlot(eActiveInventorySlot.mainHand, WEAPON_INVENTORY_SLOT_PRIMARY_1)
	    wait 0.7
	    if(IsValid( player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 ) ))
	    	player.SetActiveWeaponBySlot(eActiveInventorySlot.mainHand, WEAPON_INVENTORY_SLOT_PRIMARY_0)
	}
}


void function SummonPlayersInACircle(entity player0)
{
	vector pos = player0.GetOrigin()
	pos.z += 5
	Message(player0,"CIRCLE FIGHT NOW!", "", 5)
    for(int i = 0 ; i < GetPlayerArray().len() ; i++)
	{
		entity p = GetPlayerArray()[i]
		if(!IsValid( p ) || p == player0)
		    continue

		float r = float(i) / float( GetPlayerArray().len() ) * 2 * PI
		TeleportFRPlayer(p, pos + 150.0 * <sin( r ), cos( r ), 0.0>, <0, 0, 0>)
		Message(p,"CIRCLE FIGHT NOW!", "", 5)
	}
}

void function __GiveWeapon( entity player, array<string> WeaponData, int slot, int select)
{
	array<string> Data = split(WeaponData[select], " ")
	string weaponclass = Data[0]

	array<string> Mods
	foreach(string mod in Data)
	{
		if(strip(mod) != "" && strip(mod) != weaponclass)
		    Mods.append( strip(mod) )
	}

	if(IsValid(player))
	    player.GiveWeapon( weaponclass , slot, Mods )
}

void function GiveRandomPrimaryWeaponMetagame(entity player)
{
	int slot = WEAPON_INVENTORY_SLOT_PRIMARY_0

    array<string> Weapons = [
		"mp_weapon_r97 optic_cq_hcog_classic barrel_stabilizer_l4_flash_hider stock_tactical_l3 bullets_mag_l3",
		"mp_weapon_rspn101 optic_cq_hcog_bruiser barrel_stabilizer_l4_flash_hider stock_tactical_l3 bullets_mag_l3",
		"mp_weapon_vinson optic_cq_hcog_bruiser stock_tactical_l3 highcal_mag_l3"
	]

	__GiveWeapon( player, Weapons, slot, RandomIntRange( 0, Weapons.len() ) )
}

void function GiveRandomSecondaryWeaponMetagame(entity player)
{
	int slot = WEAPON_INVENTORY_SLOT_PRIMARY_1

    array<string> Weapons = [
		"mp_weapon_wingman optic_cq_hcog_classic highcal_mag_l2",
		"mp_weapon_energy_shotgun shotgun_bolt_l2",
		"mp_weapon_shotgun shotgun_bolt_l2",
		"mp_weapon_mastiff",
		"mp_weapon_wingman optic_cq_hcog_classic highcal_mag_l1",
	]

	__GiveWeapon( player, Weapons, slot, RandomIntRange( 0, Weapons.len() ) )
}

void function GiveRandomPrimaryWeapon(entity player)
{
	int slot = WEAPON_INVENTORY_SLOT_PRIMARY_0

    array<string> Weapons = [
		"mp_weapon_r97 optic_cq_hcog_classic barrel_stabilizer_l4_flash_hider stock_tactical_l3 bullets_mag_l2",
		"mp_weapon_rspn101 optic_cq_hcog_bruiser barrel_stabilizer_l4_flash_hider stock_tactical_l3 bullets_mag_l2",
		"mp_weapon_vinson optic_cq_hcog_bruiser stock_tactical_l3 highcal_mag_l3",
		"mp_weapon_hemlok optic_cq_hcog_bruiser stock_tactical_l3 highcal_mag_l3 barrel_stabilizer_l4_flash_hider",
		"mp_weapon_pdw optic_cq_hcog_classic stock_tactical_l3 highcal_mag_l3",
		"mp_weapon_lmg optic_cq_hcog_bruiser highcal_mag_l3 barrel_stabilizer_l3 stock_tactical_l3",
        "mp_weapon_energy_ar optic_cq_hcog_bruiser energy_mag_l3 stock_tactical_l3 hopup_turbocharger",
        "mp_weapon_alternator_smg optic_cq_hcog_classic bullets_mag_l3 stock_tactical_l3",
        "mp_weapon_lstar",
        "mp_weapon_wingman highcal_mag_l1",
        "mp_weapon_dmr optic_cq_hcog_bruiser highcal_mag_l2 barrel_stabilizer_l2 stock_sniper_l3",
        "mp_weapon_esaw optic_cq_hcog_classic energy_mag_l1 barrel_stabilizer_l4_flash_hider",
        "mp_weapon_sniper",
	]

	__GiveWeapon( player, Weapons, slot, RandomIntRange( 0, Weapons.len() ) )
}

void function GiveRandomSecondaryWeapon( entity player)
{
	int slot = WEAPON_INVENTORY_SLOT_PRIMARY_1

    array<string> Weapons = [
		"mp_weapon_wingman optic_cq_hcog_classic highcal_mag_l1",
		"mp_weapon_energy_shotgun shotgun_bolt_l1",
		"mp_weapon_shotgun shotgun_bolt_l1 ",
		"mp_weapon_mastiff",
		"mp_weapon_autopistol optic_cq_hcog_classic bullets_mag_l1",
		"mp_weapon_shotgun_pistol shotgun_bolt_l3",
		"mp_weapon_defender optic_sniper stock_sniper_l2",
		"mp_weapon_doubletake energy_mag_l3",
		"mp_weapon_g2 bullets_mag_l3 barrel_stabilizer_l4_flash_hider stock_sniper_l3 hopup_double_tap",
		"mp_weapon_semipistol bullets_mag_l2",
	]

	__GiveWeapon( player, Weapons, slot, RandomIntRange( 0, Weapons.len() ) )
}

void function GiveActualGungameWeapon(int index, entity player)
{
	int slot = WEAPON_INVENTORY_SLOT_PRIMARY_0

    array<string> Weapons = [
		"mp_weapon_r97 optic_cq_hcog_classic barrel_stabilizer_l4_flash_hider stock_tactical_l3 bullets_mag_l2",
		"mp_weapon_wingman optic_cq_hcog_classic highcal_mag_l1",
		"mp_weapon_rspn101 optic_cq_hcog_bruiser barrel_stabilizer_l4_flash_hider stock_tactical_l3 bullets_mag_l2",
		"mp_weapon_energy_shotgun shotgun_bolt_l1",
		"mp_weapon_vinson optic_cq_hcog_bruiser stock_tactical_l3 highcal_mag_l3",
		"mp_weapon_shotgun shotgun_bolt_l1",
		"mp_weapon_hemlok optic_cq_hcog_bruiser stock_tactical_l3 highcal_mag_l3 barrel_stabilizer_l4_flash_hider",
		"mp_weapon_mastiff",
		"mp_weapon_pdw optic_cq_hcog_classic stock_tactical_l3 highcal_mag_l3",
		"mp_weapon_autopistol optic_cq_hcog_classic bullets_mag_l1",
		"mp_weapon_lmg optic_cq_hcog_bruiser highcal_mag_l3 barrel_stabilizer_l3 stock_tactical_l3",
		"mp_weapon_shotgun_pistol shotgun_bolt_l3",
		"mp_weapon_rspn101 optic_cq_hcog_classic stock_tactical_l1 bullets_mag_l2",
		"mp_weapon_defender optic_ranged_hcog stock_sniper_l2",
		"mp_weapon_energy_ar optic_cq_hcog_bruiser energy_mag_l3 stock_tactical_l3 hopup_turbocharger",
		"mp_weapon_wingman",
		"mp_weapon_alternator_smg optic_cq_hcog_classic bullets_mag_l3 stock_tactical_l3",
		"mp_weapon_semipistol",
		"mp_weapon_lstar",
		"mp_weapon_g2",
		"mp_weapon_shotgun_pistol",
		"mp_weapon_esaw optic_cq_hcog_bruiser energy_mag_l1 barrel_stabilizer_l2",
		"mp_weapon_doubletake energy_mag_l3",
		"mp_weapon_rspn101 optic_cq_hcog_classic bullets_mag_l1 barrel_stabilizer_l1 stock_tactical_l1",
		"mp_weapon_wingman highcal_mag_l1",
		"mp_weapon_shotgun",
		"mp_weapon_energy_shotgun",
		"mp_weapon_vinson stock_tactical_l1 highcal_mag_l2",
		"mp_weapon_r97 optic_cq_threat bullets_mag_l1 barrel_stabilizer_l3 stock_tactical_l1",
		"mp_weapon_autopistol",
		"mp_weapon_mastiff",
		"mp_weapon_dmr optic_cq_hcog_bruiser highcal_mag_l2 barrel_stabilizer_l2 stock_sniper_l3",
		"mp_weapon_pdw stock_tactical_l1 highcal_mag_l1",
		"mp_weapon_esaw optic_cq_hcog_classic energy_mag_l1 barrel_stabilizer_l4_flash_hider",
		"mp_weapon_alternator_smg optic_cq_hcog_classic barrel_stabilizer_l2",
		"mp_weapon_sniper",
		"mp_weapon_defender optic_sniper stock_sniper_l2",
		"mp_weapon_esaw optic_cq_holosight_variable",
		"mp_weapon_rspn101 optic_cq_holosight_variable",
		"mp_weapon_vinson",
		"mp_weapon_r97 ",
		"mp_weapon_g2 bullets_mag_l3 barrel_stabilizer_l4_flash_hider stock_sniper_l3 hopup_double_tap",
		"mp_weapon_semipistol bullets_mag_l2",
	]

	__GiveWeapon( player, Weapons, slot, RandomIntRange( 0, Weapons.len() ) )
}


void function GiveRandomTac(entity player)
{
    array<string> Weapons = [
		"mp_ability_grapple",
		"mp_ability_phase_walk",
		"mp_ability_heal",
		"mp_weapon_bubble_bunker",
		"mp_weapon_grenade_bangalore",
		"mp_ability_area_sonar_scan",
		"mp_weapon_grenade_sonar",
		"mp_weapon_deployable_cover"
	]

	if(IsValid(player))
	    player.GiveOffhandWeapon(Weapons[ RandomIntRange( 0, Weapons.len()) ], OFFHAND_TACTICAL)
}

void function GiveRandomUlt(entity player )
{
    array<string> Weapons = [
		"mp_weapon_grenade_gas",
		"mp_weapon_jump_pad",
		"mp_weapon_phase_tunnel",
		"mp_ability_3dash",
		"mp_ability_hunt_mode",
		"mp_weapon_grenade_defensive_bombardment",
	]

	if(IsValid(player))
	    player.GiveOffhandWeapon(Weapons[ RandomIntRange( 0, Weapons.len()) ],  OFFHAND_ULTIMATE)
}

void function OnShipButtonUsed( entity panel, entity player, int useInputFlags )
{
	player.MakeInvisible()
	player.StartObserverMode( OBS_MODE_CHASE )
	player.SetObserverTarget( file.supercooldropship )
}

vector function ShipSpot()
{
	switch(RandomIntRange(0,11))
	{
	    case 0: return <0,0,30>
	    case 1: return <35,0,30>
	    case 2: return <-35,0,30>
	    case 3: return <0,35,30>
	    case 4: return <35,35,30>
	    case 5: return <-35,35,30>
	    case 6: return <0,70,30>
	    case 7: return <35,70,30>
	    case 8: return <-35,70,30>
	    case 9: return <0,105,30>
	    case 10: return <35,105,30>
	    case 11: return <-35,105,30>
		default: return <0,0,30>
	}
	unreachable
}


void function CreateDropShipTriggerArea()
{
	entity trigger = CreateEntity( "trigger_cylinder" )
	trigger.SetRadius( 100 )
	trigger.SetAboveHeight( 100 ) //Still not quite a sphere, will see if close enough
	trigger.SetBelowHeight( 100 )
	trigger.SetOrigin( file.supercooldropship.GetOrigin() )
	trigger.SetParent( file.supercooldropship )
	DispatchSpawn( trigger )

	trigger.SearchForNewTouchingEntity()

	OnThreadEnd(
	function() : ( trigger )
		{
			trigger.Destroy()
		}
	)

	while ( file.isshipalive )
	{
		foreach( touchingEnt in trigger.GetTouchingEntities()  )
		{
			if(touchingEnt.IsPlayer() && touchingEnt.GetParent() != file.supercooldropship)
			{
				touchingEnt.SetThirdPersonShoulderModeOff()
				vector shipspot = ShipSpot()
				touchingEnt.SetAbsOrigin( file.supercooldropship.GetOrigin() + shipspot )
				touchingEnt.SetParent(file.supercooldropship)
			}
		}
		wait 0.01
	}
}

void function CreateShipRoomFallTriggers()
{
	entity trigger = CreateEntity( "trigger_cylinder" )
	trigger.SetRadius( 2000 )
	trigger.SetAboveHeight( 25 ) //Still not quite a sphere, will see if close enough
	trigger.SetBelowHeight( 25 )

	if (GetMapName() == "mp_rr_desertlands_64k_x_64k" || GetMapName() == "mp_rr_desertlands_64k_x_64k_nx")
		trigger.SetOrigin( <-19459, 2127, 5404> )
	else if(GetMapName() == "mp_rr_canyonlands_mu1" || GetMapName() == "mp_rr_canyonlands_mu1_night" || GetMapName() == "mp_rr_canyonlands_64k_x_64k")
		trigger.SetOrigin( <-19459, 2127, 17404> )

	DispatchSpawn( trigger )

	trigger.SearchForNewTouchingEntity()

	OnThreadEnd(
	function() : ( trigger )
		{
			trigger.Destroy()
		}
	)

	while ( file.FallTriggersEnabled )
	{
		foreach( touchingEnt in trigger.GetTouchingEntities() )
		{
			if( touchingEnt.IsPlayer() )
			{
				if (GetMapName() == "mp_rr_desertlands_64k_x_64k" || GetMapName() == "mp_rr_desertlands_64k_x_64k_nx")
					touchingEnt.SetOrigin( <-19459, 2127, 6404> )
				else if(GetMapName() == "mp_rr_canyonlands_mu1" || GetMapName() == "mp_rr_canyonlands_mu1_night" || GetMapName() == "mp_rr_canyonlands_64k_x_64k")
					touchingEnt.SetOrigin( <-19459, 2127, 18404> )
			}
		}
		wait 0.01
	}
}

array<ConsumableInventoryItem> function FlowStateGetAllDroppableItems( entity player )
{
	array<ConsumableInventoryItem> final = []

	// Consumable inventory
	final.extend( SURVIVAL_GetPlayerInventory( player ) )

	// Weapon related items
	foreach ( weapon in SURVIVAL_GetPrimaryWeapons( player ) )
	{
		LootData data = SURVIVAL_GetLootDataFromWeapon( weapon )
		if ( data.ref == "" )
			continue

		// Add the weapon
		ConsumableInventoryItem item

		item.type = data.index
		item.count = weapon.GetWeaponPrimaryClipCount()

		final.append( item )

		foreach ( esRef, mod in GetAllWeaponAttachments( weapon ) )
		{
			if ( !SURVIVAL_Loot_IsRefValid( mod ) )
				continue

			if ( data.baseMods.contains( mod ) )
				continue

			LootData attachmentData = SURVIVAL_Loot_GetLootDataByRef( mod )

			// Add the attachment
			ConsumableInventoryItem attachmentItem

			attachmentItem.type = attachmentData.index
			attachmentItem.count = 1

			final.append( attachmentItem )
		}
	}

	// Non-weapon equipment slots
	foreach ( string ref, EquipmentSlot es in EquipmentSlot_GetAllEquipmentSlots() )
	{
		if ( EquipmentSlot_IsMainWeaponSlot( ref ) || EquipmentSlot_IsAttachmentSlot( ref ) )
			continue

		LootData data = EquipmentSlot_GetEquippedLootDataForSlot( player, ref )
		if ( data.ref == "" )
			continue

		// Add the equipped loot
		ConsumableInventoryItem equippedItem

		equippedItem.type = data.index
		equippedItem.count = 1

		final.append( equippedItem )
	}

	return final
}


void function CreateFlowStateDeathBoxForPlayer( entity victim, entity attacker, var damageInfo )
{
	entity deathBox = FlowState_CreateDeathBox( victim, true )

	foreach ( invItem in FlowStateGetAllDroppableItems( victim ) )
	{
		//Message(victim,"DEBUG", invItem.type.tostring(), 10)
		if( invItem.type == 44 || invItem.type == 45 || invItem.type == 46 || invItem.type == 47 || invItem.type == 48 || invItem.type == 53 || invItem.type == 54 || invItem.type == 55 || invItem.type == 56 )
		    continue
		else{
		    LootData data = SURVIVAL_Loot_GetLootDataByIndex( invItem.type )
		    entity loot = SpawnGenericLoot( data.ref, deathBox.GetOrigin(), deathBox.GetAngles(), invItem.count )
		    AddToDeathBox( loot, deathBox )
		}
	}

	UpdateDeathBoxHighlight( deathBox )

	foreach ( func in svGlobal.onDeathBoxSpawnedCallbacks )
		func( deathBox, attacker, damageInfo != null ? DamageInfo_GetDamageSourceIdentifier( damageInfo ) : 0 )
}


entity function FlowState_CreateDeathBox( entity player, bool hasCard )
{
	entity box = CreatePropDeathBox_NoDispatchSpawn( DEATH_BOX, player.GetOrigin(), <0, 45, 0>, 6 )
	box.kv.fadedist = 10000
	if ( hasCard )
		SetTargetName( box, DEATH_BOX_TARGETNAME )

	DispatchSpawn( box )

	box.RemoveFromAllRealms()
	box.AddToOtherEntitysRealms( player )
	box.Solid()
	box.SetUsable()
	box.SetUsableValue( USABLE_BY_ALL | USABLE_CUSTOM_HINTS )
	box.SetOwner( player )
	box.SetNetInt( "ownerEHI", player.GetEncodedEHandle() )

	if ( hasCard )
	{
		box.SetNetBool( "overrideRUI", false )
		box.SetCustomOwnerName( player.GetPlayerName() )
		box.SetNetInt( "characterIndex", ConvertItemFlavorToLoadoutSlotContentsIndex( Loadout_CharacterClass() , LoadoutSlot_GetItemFlavor( ToEHI( player ) , Loadout_CharacterClass() ) ) )
	}

	if ( hasCard )
	{
		Highlight_SetNeutralHighlight( box, "sp_objective_entity" )
		Highlight_ClearNeutralHighlight( box )

		vector restPos = box.GetOrigin()
		vector fallPos = restPos + < 0, 0, 54 >

		thread (void function( entity box , vector restPos , vector fallPos) {
			entity mover = CreateScriptMover( restPos, box.GetAngles(), 0 )
			if ( IsValid( box ) )
				{
				box.SetParent( mover, "", true )
				mover.NonPhysicsMoveTo( fallPos, 0.5, 0.0, 0.5 )
				}
			wait 0.5
			if ( IsValid( box ) )
				mover.NonPhysicsMoveTo( restPos, 0.5, 0.5, 0.0 )
			wait 0.5
			if ( IsValid( box ) )
				box.ClearParent()
			if ( IsValid( mover ) )
				mover.Destroy()

		}) ( box , restPos , fallPos)

		thread (void function( entity box) {
			wait 20
			if(IsValid(box))
				box.Destroy()
		}) ( box )
	}

	return box
}

void function PlayerRestoreShieldsFIESTA(entity player, int shields) {
    if(IsValidPlayer(player) && IsAlive( player ))
        player.SetShieldHealth(shielddd(shields, 0, player.GetShieldHealthMax()))
}

void function PlayerRestoreHPFIESTA(entity player, int health) {
    if(IsValidPlayer(player) && IsAlive( player ))
        player.SetHealth( health )
}

int function shielddd(int value, int min, int max) {
    if(value < min) return min
    else if (value > max) return max
    else return value

    unreachable
}

void function UpgradeShields(entity player, bool died)
{
    if (!IsValid(player)) return

    if (died && FlowState_FIESTAShieldsStreak()) {
        player.SetPlayerGameStat( PGS_TITAN_KILLS, 0 )
        Inventory_SetPlayerEquipment(player, BLUE_SHIELD, "armor")
    } else if (FlowState_FIESTAShieldsStreak())
	{
        player.SetPlayerGameStat( PGS_TITAN_KILLS, player.GetPlayerGameStat( PGS_TITAN_KILLS ) + 1)

        switch (player.GetPlayerGameStat( PGS_TITAN_KILLS ))
		{
	    	case 1:
            case 2:
            case 3:
			case 4:
			    Inventory_SetPlayerEquipment(player, BLUE_SHIELD, "armor")
			break
			case 5:
				Inventory_SetPlayerEquipment(player, PURPLE_SHIELD, "armor")
				foreach(sPlayer in GetPlayerArray())
				    Message(sPlayer,"KILL STREAK", player.GetPlayerName() + " got 5 kill streak!", 4, "")
            break
            case 6:
			case 7:
				Inventory_SetPlayerEquipment(player, PURPLE_SHIELD, "armor")
            break
			case 8:
				foreach(sPlayer in GetPlayerArray())
				    Message(sPlayer,"EXTRA SHIELD KILL STREAK", player.GetPlayerName() + " got 8 kill streak and extra shield!", 5, "")
			break
			case 15:
				foreach(sPlayer in GetPlayerArray())
				    Message(sPlayer,"15 KILL STREAK", player.GetPlayerName() + " got 15 kill streak!", 5, "")
			break
			case 20:
				foreach(sPlayer in GetPlayerArray())
				    Message(sPlayer,"20 BOMB KILL STREAK", player.GetPlayerName() + " got a 20 bomb!", 5, "")
			break
			case 25:
				foreach(sPlayer in GetPlayerArray())
				    Message(sPlayer,"LEGENDARY KILL STREAK", player.GetPlayerName() + " got 30 kill streak!", 5, "")
			break
			case 35:
				foreach(sPlayer in GetPlayerArray())
				    Message(sPlayer,"PREDATOR SUPREMACY", player.GetPlayerName() + " got 35 kill streak!", 5, "")
			break
			case 50:
				foreach(sPlayer in GetPlayerArray())
				    Message(sPlayer,"CHEATER DETECTED!", player.GetPlayerName() + " got 50 kill streak, report him!", 5, "")
            break
			default:
            break
        }

		GiveFlowstateOvershield(player)

    } else if (!FlowState_FIESTAShieldsStreak())
	    PlayerRestoreHP(player, 100, Equipment_GetDefaultShieldHP())
	else if (FlowState_FIESTAShieldsStreak()){
        PlayerRestoreShieldsFIESTA(player, player.GetShieldHealthMax())
        PlayerRestoreHPFIESTA(player, 100)
	}
}

void function KillStreakAnnouncer(entity player, bool died) {

    if (!IsValid(player)) return

    if (died)
        player.SetPlayerGameStat( PGS_TITAN_KILLS, 0 )
    else {
        switch (player.GetPlayerGameStat( PGS_TITAN_KILLS )) {
			case 5:
				foreach(sPlayer in GetPlayerArray())
				    Message(sPlayer,"KILL STREAK", player.GetPlayerName() + " got 5 kill streak!", 4, "")
			case 10:
				GiveFlowstateOvershield(player)
				foreach(sPlayer in GetPlayerArray())
				    Message(sPlayer,"EXTRA SHIELD KILL STREAK", player.GetPlayerName() + " got 10 kill streak and extra shield!", 5, "")
            break
			case 15:
				GiveFlowstateOvershield(player)
				foreach(sPlayer in GetPlayerArray())
				    Message(sPlayer,"15 KILL STREAK", player.GetPlayerName() + " got 15 kill streak and extra shield!", 5, "")
			case 20:
				GiveFlowstateOvershield(player)
				foreach(sPlayer in GetPlayerArray())
				    Message(sPlayer,"20 BOMB KILL STREAK", player.GetPlayerName() + " got a 20 bomb and extra shield!", 5, "")
            break
			case 25:
				GiveFlowstateOvershield(player)
				foreach(sPlayer in GetPlayerArray())
				Message(sPlayer,"PREDATOR SUPREMACY", player.GetPlayerName() + " got 25 kill streak and extra shield!", 5, "")
            break
			default:
                break
        }
    }
}

#if SERVER
void function GiveFlowstateOvershield( entity player, bool isOvershieldFromGround = false)
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
{
	player.SetShieldHealthMax( FlowState_ExtrashieldValue() )
	player.SetShieldHealth( FlowState_ExtrashieldValue() )
	if(isOvershieldFromGround){
			foreach(sPlayer in GetPlayerArray()){
			Message(sPlayer,"EXTRA SHIELD PROVIDED", player.GetPlayerName() + " has 50 extra shield.", 5, "")
		}
	}
}
#endif

void function GiveGungameWeapon(entity player) {
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
	int WeaponIndex = player.GetPlayerNetInt( "kills" )
	int realweaponIndex = WeaponIndex
	int MaxWeapons = 42
		if (WeaponIndex > MaxWeapons) {
        file.tdmState = eTDMState.NEXT_ROUND_NOW
		foreach (sPlayer in GetPlayerArray())
			{
			sPlayer.SetPlayerNetInt("kills", 0) //Reset for kills
	    	sPlayer.SetPlayerNetInt("assists", 0) //Reset for deaths
			sPlayer.p.playerDamageDealt = 0.0
			}
		}

	if(!FlowState_GungameRandomAbilities())
	{
		string tac = GetCurrentPlaylistVarString("flowstateGUNGAME_tactical", "~~none~~")
		string ult = GetCurrentPlaylistVarString("flowstateGUNGAME_ultimate", "~~none~~")

		entity tactical = player.GetOffhandWeapon( OFFHAND_TACTICAL )
        entity ultimate = player.GetOffhandWeapon( OFFHAND_ULTIMATE )

		float oldTacticalChargePercent = 0.0
                if( IsValid( tactical ) ) {
                    player.TakeOffhandWeapon( OFFHAND_TACTICAL )
                    oldTacticalChargePercent = float( tactical.GetWeaponPrimaryClipCount()) / float(tactical.GetWeaponPrimaryClipCountMax() )
                }
				if(tac != "~~none~~" && tac != "")
					player.GiveOffhandWeapon(tac, OFFHAND_TACTICAL)

				entity newTactical = player.GetOffhandWeapon( OFFHAND_TACTICAL )
				if(IsValid(newTactical))
					newTactical.SetWeaponPrimaryClipCount( int( newTactical.GetWeaponPrimaryClipCountMax() * oldTacticalChargePercent ) )

				if( IsValid( ultimate ) ) player.TakeOffhandWeapon( OFFHAND_ULTIMATE )

				if(ult != "~~none~~" && ult != "")
					player.GiveOffhandWeapon(ult, OFFHAND_ULTIMATE)
	}
	try{
	//give gungame weapon
	player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
	GiveActualGungameWeapon(realweaponIndex, player)
	//give secondary
	string sec = GetCurrentPlaylistVarString("flowstateGUNGAMESecondary", "~~none~~")
	player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_1 )
	player.GiveWeapon( sec, WEAPON_INVENTORY_SLOT_PRIMARY_1)

	if (sec != "") {
			array<string> attachments = []

			for(int i = 0; GetCurrentPlaylistVarString("flowstateGUNGAMESecondary" + "_" + i.tostring(), "~~none~~") != "~~none~~"; i++)
			{
				if(GetCurrentPlaylistVarString("flowstateGUNGAMESecondary" + "_" + i.tostring(), "~~none~~") == ""){
				continue
				}
				else{
				attachments.append(GetCurrentPlaylistVarString("flowstateGUNGAMESecondary" + "_" + i.tostring(), "~~none~~"))}
			}
			player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_1 )
			player.GiveWeapon(sec, WEAPON_INVENTORY_SLOT_PRIMARY_1, attachments)
	}
	//entity primary = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
	//if( IsValid( primary ) && !primary.IsWeaponOffhand() ) player.SetActiveWeaponBySlot(eActiveInventorySlot.mainHand, GetSlotForWeapon(player, primary))
		}catch(e113){}
}

 // ██████   █████  ███    ███ ███████     ██       ██████   ██████  ██████
// ██       ██   ██ ████  ████ ██          ██      ██    ██ ██    ██ ██   ██
// ██   ███ ███████ ██ ████ ██ █████       ██      ██    ██ ██    ██ ██████
// ██    ██ ██   ██ ██  ██  ██ ██          ██      ██    ██ ██    ██ ██
 // ██████  ██   ██ ██      ██ ███████     ███████  ██████   ██████  ██

void function RunTDM()
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
{
    WaitForGameState(eGameState.Playing)
    AddSpawnCallback("prop_dynamic", _OnPropDynamicSpawned)

	if(!Flowstate_DoorsEnabled()){
		array<entity> doors = GetAllPropDoors()

		foreach(entity door in doors)
			if(IsValid(door))
				door.Destroy()
	}

    while(true)
	{
		//VotingPhase()
		SimpleChampionUI()
		WaitFrame()
	}
    WaitForever()
}

void function SimpleChampionUI(){
/////////////Retículo Endoplasmático#5955 CaféDeColombiaFPS///////////////////
{
	printt("Flowstate DEBUG - Game is starting.")

	foreach(player in GetPlayerArray())
		if(IsValid(player)) ScreenFade( player, 0, 0, 0, 255, 1.5, 1.5, FFADE_IN | FFADE_PURGE ) //let's do this before destroy player props so it looks good in custom maps

    DestroyPlayerProps()
	isBrightWaterByZer0 = false

    PlayerTrail(GetBestPlayer(),0)

	SetGameState(eGameState.Playing)
	file.tdmState = eTDMState.IN_PROGRESS
	file.FallTriggersEnabled = true

	foreach(player in GetPlayerArray())
	{
			if(IsValid(player))
			{
				_HandleRespawn(player)
					if(FlowState_Gungame())
						{
							GiveGungameWeapon(player)
						}
				player.UnforceStand()
				player.UnfreezeControlsOnServer()
				HolsterAndDisableWeapons( player )
			}
	}

	if (!file.mapIndexChanged)
		{
			file.nextMapIndex = (file.nextMapIndex + 1 ) % file.locationSettings.len()
		}

	if (FlowState_LockPOI()) {
		file.nextMapIndex = FlowState_LockedPOI()
	}

	int choice = file.nextMapIndex
	file.mapIndexChanged = false
	file.selectedLocation = file.locationSettings[choice]
	file.thisroundDroppodSpawns = GetNewFFADropShipLocations(file.selectedLocation.name, GetMapName())
	printt("Flowstate DEBUG - Next round location is: " + file.selectedLocation.name)

	if(GetMapName() == "mp_rr_desertlands_64k_x_64k" || GetMapName() == "mp_rr_desertlands_64k_x_64k_nx" || GetMapName() == "mp_rr_canyonlands_mu1" || GetMapName() == "mp_rr_canyonlands_mu1_night" || GetMapName() == "mp_rr_canyonlands_64k_x_64k")
	{
		thread CreateShipRoomFallTriggers()
	}
	if (FlowState_RandomGuns() )
    {
        file.randomprimary = RandomIntRangeInclusive( 0, 15 )
        file.randomsecondary = RandomIntRangeInclusive( 0, 6 )
    } else if (FlowState_RandomGunsMetagame())
	{
		file.randomprimary = RandomIntRangeInclusive( 0, 2 )
        file.randomsecondary = RandomIntRangeInclusive( 0, 4 )
	} else if (FlowState_RandomGunsEverydie())
	{
		file.randomprimary = RandomIntRangeInclusive( 0, 23 )
        file.randomsecondary = RandomIntRangeInclusive( 0, 18 )
	}

	if(file.selectedLocation.name == "TTV Building" && FlowState_ExtrashieldsEnabled()){
		DestroyPlayerProps()
		CreateGroundMedKit(<10725, 5913,-4225>)
	} else if(file.selectedLocation.name == "Skill trainer By Colombia" && FlowState_ExtrashieldsEnabled()){
		DestroyPlayerProps()
		CreateGroundMedKit(<17247,31823,-310>)
		thread SkillTrainerLoad()
	} else if(file.selectedLocation.name == "Skill trainer By Colombia" )
	{
		printt("Flowstate DEBUG - creating props for Skill Trainer.")
		DestroyPlayerProps()
		thread SkillTrainerLoad()
	} else if(file.selectedLocation.name == "Brightwater By Zer0bytes" )
	{
		printt("Flowstate DEBUG - creating props for Brightwater.")
		isBrightWaterByZer0 = true
		DestroyPlayerProps()
		thread WorldEntities()
		wait 1
		thread BrightwaterLoad()
		wait 1.5
		thread BrightwaterLoad2()
		wait 1.5
		thread BrightwaterLoad3()
	} else if(file.selectedLocation.name == "Cave By BlessedSeal" ){
		printt("Flowstate DEBUG - creating props for Cave.")
		DestroyPlayerProps()
		thread SpawnEditorPropsSeal()
	} else if(file.selectedLocation.name == "Gaunlet" && FlowState_ExtrashieldsEnabled()){
		DestroyPlayerProps()
		printt("Flowstate DEBUG - creating Gaunlet Extrashield.")
		CreateGroundMedKit(<-21289, -12030, 3060>)
	} else if (file.selectedLocation.name == "White Forest By Zer0Bytes"){
		DestroyPlayerProps()
		printt("Flowstate DEBUG - creating props for White Forest.")
		thread SpawnWhiteForestProps()
	} else if (file.selectedLocation.name == "Custom map by Biscutz"){
		DestroyPlayerProps()
		printt("Flowstate DEBUG - creating props for Map by Biscutz.")
		thread LoadMapByBiscutz1()
		thread LoadMapByBiscutz2()
	}
    foreach(player in GetPlayerArray())
    {
        try {
            if(IsValid(player))
            {
		        RemoveCinematicFlag(player, CE_FLAG_HIDE_MAIN_HUD | CE_FLAG_EXECUTION)
		        player.SetThirdPersonShoulderModeOff()
		        _HandleRespawn(player)
				ClearInvincible(player)
		        DeployAndEnableWeapons(player)
				EnableOffhandWeapons( player )

				entity primary = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
				entity secondary = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 )
				entity tactical = player.GetOffhandWeapon( OFFHAND_INVENTORY )
				entity ultimate = player.GetOffhandWeapon( OFFHAND_LEFT )

				if(IsValid(primary) && primary.UsesClipsForAmmo())
					primary.SetWeaponPrimaryClipCount(primary.GetWeaponPrimaryClipCountMax())
				if(IsValid(secondary) && secondary.UsesClipsForAmmo())
					secondary.SetWeaponPrimaryClipCount( secondary.GetWeaponPrimaryClipCountMax())
				if(IsValid(tactical) && tactical.UsesClipsForAmmo())
					tactical.SetWeaponPrimaryClipCount( tactical.GetWeaponPrimaryClipCountMax() )
				if(IsValid(ultimate) && ultimate.UsesClipsForAmmo())
					ultimate.SetWeaponPrimaryClipCount( ultimate.GetWeaponPrimaryClipCountMax() )
			}
	    } catch(e3){}
    }
}

try {
if(GetBestPlayer()==PlayerWithMostDamage())
{
	foreach(player in GetPlayerArray())
    {
		string nextlocation = file.selectedLocation.name
		string subtext
		if(GetBestPlayerName() != "-still nobody-")
			subtext = "\n           CHAMPION: " + GetBestPlayerName() + " / " + GetBestPlayerScore() + " kills. / " + GetDamageOfPlayerWithMostDamage() + " damage."
		else subtext = ""
			Message(player, file.selectedLocation.name, subtext, 25, "diag_ap_aiNotify_circleTimerStartNext_02")
		file.previousChampion=GetBestPlayer()
		file.previousChallenger=PlayerWithMostDamage()
		GameRules_SetTeamScore(player.GetTeam(), 0)
		file.deathPlayersCounter = 0
	}
}
else{
	foreach(player in GetPlayerArray())
    {
		string nextlocation = file.selectedLocation.name
		string subtext
		if(GetBestPlayerName() != "-still nobody-")
			subtext = "\n           CHAMPION: " + GetBestPlayerName() + " / " + GetBestPlayerScore() + " kills. \n    CHALLENGER:  " + PlayerWithMostDamageName() + " / " + GetDamageOfPlayerWithMostDamage() + " damage."
		else subtext = ""
			Message(player, file.selectedLocation.name, subtext, 25, "diag_ap_aiNotify_circleTimerStartNext_02")
		file.previousChampion=GetBestPlayer()
		file.previousChallenger=PlayerWithMostDamage()
		GameRules_SetTeamScore(player.GetTeam(), 0)
		file.deathPlayersCounter = 0
	}
}
} catch(e4){}
printt("Flowstate DEBUG - Clearing last round stats.")
foreach(player in GetPlayerArray())
    {
        if(IsValidPlayer(player))
        {
			player.p.playerDamageDealt = 0.0
			if (FlowState_ResetKillsEachRound() && IsValidPlayer(player))
			{
				player.SetPlayerNetInt("kills", 0) //Reset for kills
	    		player.SetPlayerNetInt("assists", 0) //Reset for deaths
			}

			if(FlowState_Gungame())
			{
			player.SetPlayerGameStat( PGS_TITAN_KILLS, 0)
			KillStreakAnnouncer(player, true)
			}

			if(FlowState_RandomGunsEverydie()){
			player.SetPlayerGameStat( PGS_TITAN_KILLS, 0)
			UpgradeShields(player, true)
			}
		}
	}
ResetAllPlayerStats()
file.ringBoundary = CreateRingBoundary(file.selectedLocation)
printt("Flowstate DEBUG - Bubble created, executing SimpleChampionUI.")

float endTime = Time() + FlowState_RoundTime()
printt("Flowstate DEBUG - TDM/FFA gameloop Round started.")

foreach(player in GetPlayerArray())
    {
	thread WpnPulloutOnRespawn(player)
	}

if(GetCurrentPlaylistVarBool("flowstateEndlessFFAorTDM", false ))
{
	while(true)
	{
		WaitFrame()
	}
}

if (FlowState_Timer()){
while( Time() <= endTime )
	{
		if(Time() == endTime-900)
		{
				foreach(player in GetPlayerArray())
				{
					if(IsValid(player))
					{
						Message(player,"15 MINUTES REMAINING!","", 5)
					}
				}
			}
			if(Time() == endTime-600)
			{
				foreach(player in GetPlayerArray())
				{
					if(IsValid(player))
					{
						Message(player,"10 MINUTES REMAINING!","", 5)
					}
				}
			}
			if(Time() == endTime-300)
			{
				foreach(player in GetPlayerArray())
				{
					if(IsValid(player))
					{
						Message(player,"5 MINUTES REMAINING!","", 5)
					}
				}
			}
			if(Time() == endTime-120)
			{
				foreach(player in GetPlayerArray())
				{
					if(IsValid(player))
					{
						Message(player,"2 MINUTES REMAINING!","", 5)
					}
				}
			}
			if(Time() == endTime-60)
			{
				foreach(player in GetPlayerArray())
				{
					if(IsValid(player))
					{
						Message(player,"1 MINUTE REMAINING!","", 5, "diag_ap_aiNotify_circleMoves60sec")
					}
				}
			}
			if(Time() == endTime-30)
			{
				foreach(player in GetPlayerArray())
				{
					if(IsValid(player))
					{
						Message(player,"30 SECONDS REMAINING!","", 5, "diag_ap_aiNotify_circleMoves30sec")
					}
				}
			}
			if(Time() == endTime-10)
			{
				foreach(player in GetPlayerArray())
				{
					if(IsValid(player))
					{
						Message(player,"10 SECONDS REMAINING!", "\n The battle is over.", 8, "diag_ap_aiNotify_circleMoves10sec")
					}
				}
			}
			if(file.tdmState == eTDMState.NEXT_ROUND_NOW){
				printt("Flowstate DEBUG - tdmState is eTDMState.NEXT_ROUND_NOW Loop ended.")
				break}
			WaitFrame()
		}
}
else if (!FlowState_Timer() ){
	while( Time() <= endTime )
		{
		if(file.tdmState == eTDMState.NEXT_ROUND_NOW) {
			printt("Flowstate DEBUG - tdmState is eTDMState.NEXT_ROUND_NOW Loop ended.")
			break}
			WaitFrame()
		}
}

foreach(player in GetPlayerArray())
    {
		if(IsValid(player) && !IsAlive(player)){
				_HandleRespawn(player)
				ClearInvincible(player)
				player.SetThirdPersonShoulderModeOn()
				HolsterAndDisableWeapons( player )
		}else if(IsValid(player) && IsAlive(player))
			{
				if(FlowState_RandomGunsEverydie() && FlowState_FIESTAShieldsStreak()){
				PlayerRestoreShieldsFIESTA(player, player.GetShieldHealthMax())
				PlayerRestoreHPFIESTA(player, 100)
				player.SetThirdPersonShoulderModeOn()
				HolsterAndDisableWeapons( player )
				} else {
				PlayerRestoreHP(player, 100, Equipment_GetDefaultShieldHP())
				player.SetThirdPersonShoulderModeOn()
				HolsterAndDisableWeapons( player )
				}
		}
	}

wait 1
foreach(entity champion in GetPlayerArray())
    {
		if(GetBestPlayer() == champion) {
		if(IsValid(champion))
			{
				 thread EmitSoundOnEntityOnlyToPlayer( champion, champion, "diag_ap_aiNotify_winnerFound_10" )
				 thread EmitSoundOnEntityExceptToPlayer( champion, champion, "diag_ap_aiNotify_winnerFound" )
				PlayerTrail(champion,1)
			}
		}
	}
foreach(player in GetPlayerArray())
    {

	 if(IsValid(player)){
	 AddCinematicFlag(player, CE_FLAG_HIDE_MAIN_HUD | CE_FLAG_EXECUTION)
	 Message(player,"- ROUND SCOREBOARD -", "\n         Name:    K  |   D   |   KD   |   Damage dealt \n \n" + ScoreboardFinal() + "\n Flowstate " + file.scriptversion + " by CaféDeColombiaFPS!", 7, "UI_Menu_RoundSummary_Results")}
	wait 0.1
	}

wait 7

foreach(player in GetPlayerArray())
    {
		if(IsValid(player)){
		ClearInvincible(player)
		RemoveCinematicFlag(player, CE_FLAG_HIDE_MAIN_HUD | CE_FLAG_EXECUTION)
		player.SetThirdPersonShoulderModeOff()
		}
	}
file.ringBoundary.Destroy()
}

//       ██ ██████  ██ ███    ██  ██████  ██
//      ██  ██   ██ ██ ████   ██ ██        ██
//      ██  ██████  ██ ██ ██  ██ ██   ███  ██
//      ██  ██   ██ ██ ██  ██ ██ ██    ██  ██
//       ██ ██   ██ ██ ██   ████  ██████  ██
// Purpose: Create The RingBoundary
entity function CreateRingBoundary(LocationSettings location)
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
{
    array<LocPair> spawns = location.spawns

    vector ringCenter
    foreach( spawn in spawns )
    {
        ringCenter += spawn.origin
    }

    ringCenter /= spawns.len()

    float ringRadius = 0

    foreach( LocPair spawn in spawns )
    {
        if( Distance( spawn.origin, ringCenter ) > ringRadius )
            ringRadius = Distance(spawn.origin, ringCenter)
    }

    ringRadius += GetCurrentPlaylistVarFloat("ring_radius_padding", 800)
	//We watch the ring fx with this entity in the threads
	entity circle = CreateEntity( "prop_script" )
	circle.SetValueForModelKey( $"mdl/fx/ar_survival_radius_1x100.rmdl" )
	circle.kv.fadedist = -1
	circle.kv.modelscale = ringRadius
	circle.kv.renderamt = 255
	circle.kv.rendercolor = FlowState_RingColor()
	circle.kv.solid = 0
	circle.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE
	circle.SetOrigin( ringCenter )
	circle.SetAngles( <0, 0, 0> )
	circle.NotSolid()
	circle.DisableHibernation()
    circle.Minimap_SetObjectScale( ringRadius / SURVIVAL_MINIMAP_RING_SCALE )
    circle.Minimap_SetAlignUpright( true )
    circle.Minimap_SetZOrder( 2 )
    circle.Minimap_SetClampToEdge( true )
    circle.Minimap_SetCustomState( eMinimapObject_prop_script.OBJECTIVE_AREA )
	SetTargetName( circle, "hotZone" )
	DispatchSpawn(circle)

    foreach ( player in GetPlayerArray() )
    {
        circle.Minimap_AlwaysShow( 0, player )
    }

	SetDeathFieldParams( ringCenter, ringRadius, ringRadius, 90000, 99999 ) // This function from the API allows client to read ringRadius from server so we can use visual effects in shared function. Colombia

	//Audio thread for ring
	foreach(sPlayer in GetPlayerArray())
		thread AudioThread(circle, sPlayer, ringRadius)

	//Damage thread for ring
	thread RingDamage(circle, ringRadius)

    return circle
}

void function AudioThread(entity circle, entity player, float radius)
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
{
	EndSignal(player, "OnDestroy")
	entity audio
	string soundToPlay = "Survival_Circle_Edge_Small"
	OnThreadEnd(
		function() : ( soundToPlay, audio)
		{

			if(IsValid(audio)) audio.Destroy()
		}
	)
	audio = CreateScriptMover()
	audio.SetOrigin( circle.GetOrigin() )
	audio.SetAngles( <0, 0, 0> )
	EmitSoundOnEntity( audio, soundToPlay )

	while(IsValid(circle)){
			if(!IsValid(player)) continue
			vector fwdToPlayer   = Normalize( <player.GetOrigin().x, player.GetOrigin().y, 0> - <circle.GetOrigin().x, circle.GetOrigin().y, 0> )
			vector circleEdgePos = circle.GetOrigin() + (fwdToPlayer * radius)
			circleEdgePos.z = player.EyePosition().z
			if ( fabs( circleEdgePos.x ) < 61000 && fabs( circleEdgePos.y ) < 61000 && fabs( circleEdgePos.z ) < 61000 )
			{
				audio.SetOrigin( circleEdgePos )
			}
		WaitFrame()
	}

	StopSoundOnEntity(audio, soundToPlay)
}

void function RingDamage( entity circle, float currentRadius)
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
{
	WaitFrame()
	const float DAMAGE_CHECK_STEP_TIME = 1.5

	while ( IsValid(circle) )
	{
		foreach ( dummy in GetNPCArray() )
		{
			if ( dummy.IsPhaseShifted() )
				continue

			float playerDist = Distance2D( dummy.GetOrigin(), circle.GetOrigin() )
			if ( playerDist > currentRadius )
			{
				dummy.TakeDamage( int( Deathmatch_GetOOBDamagePercent() / 100 * float( dummy.GetMaxHealth() ) ), null, null, { scriptType = DF_BYPASS_SHIELD | DF_DOOMED_HEALTH_LOSS, damageSourceId = eDamageSourceId.deathField } )
			}
		}

		foreach ( player in GetPlayerArray_Alive() )
		{
			if ( player.IsPhaseShifted() )
				continue

			float playerDist = Distance2D( player.GetOrigin(), circle.GetOrigin() )
			if ( playerDist > currentRadius )
			{
				Remote_CallFunction_Replay( player, "ServerCallback_PlayerTookDamage", 0, 0, 0, 0, DF_BYPASS_SHIELD | DF_DOOMED_HEALTH_LOSS, eDamageSourceId.deathField, null )
				player.TakeDamage( int( Deathmatch_GetOOBDamagePercent() / 100 * float( player.GetMaxHealth() ) ), null, null, { scriptType = DF_BYPASS_SHIELD | DF_DOOMED_HEALTH_LOSS, damageSourceId = eDamageSourceId.deathField } )
			}
		}
		wait DAMAGE_CHECK_STEP_TIME
	}
}

void function PlayerRestoreHP(entity player, float health, float shields)
{
	if(!IsValid(player)) return
	if(!IsAlive( player)) return

	player.SetHealth( health )
	Inventory_SetPlayerEquipment(player, "helmet_pickup_lv3", "helmet")
	if(shields == 0) return
	else if(shields <= 50)
		Inventory_SetPlayerEquipment(player, "armor_pickup_lv1", "armor")
	else if(shields <= 75)
		Inventory_SetPlayerEquipment(player, "armor_pickup_lv2", "armor")
	else if(shields <= 100)
		Inventory_SetPlayerEquipment(player, "armor_pickup_lv3", "armor")
	player.SetShieldHealth( shields )
}

 // ██████  ██████  ███████ ███    ███ ███████ ████████ ██  ██████ ███████     ███████ ██    ██ ███    ██  ██████ ████████ ██  ██████  ███    ██ ███████
// ██      ██    ██ ██      ████  ████ ██         ██    ██ ██      ██          ██      ██    ██ ████   ██ ██         ██    ██ ██    ██ ████   ██ ██
// ██      ██    ██ ███████ ██ ████ ██ █████      ██    ██ ██      ███████     █████   ██    ██ ██ ██  ██ ██         ██    ██ ██    ██ ██ ██  ██ ███████
// ██      ██    ██      ██ ██  ██  ██ ██         ██    ██ ██           ██     ██      ██    ██ ██  ██ ██ ██         ██    ██ ██    ██ ██  ██ ██      ██
 // ██████  ██████  ███████ ██      ██ ███████    ██    ██  ██████ ███████     ██       ██████  ██   ████  ██████    ██    ██  ██████  ██   ████ ███████

void function PlayerTrail(entity player, int onoff)
//Thanks Zee#0134//
{
	if(!IsValid(player)) return
    if (onoff == 1 )
    {
        int smokeAttachID = player.LookupAttachment( "CHESTFOCUS" )
	    vector smokeColor = <255,255,255>
		entity smokeTrailFX = StartParticleEffectOnEntityWithPos_ReturnEntity( player, GetParticleSystemIndex( $"P_grenade_thermite_trail"), FX_PATTACH_ABSORIGIN_FOLLOW, smokeAttachID, <0,0,0>, VectorToAngles( <0,0,-1> ) )

		EffectSetControlPointVector( smokeTrailFX, 1, smokeColor )
        player.p.DEV_lastDroppedSurvivalWeaponProp = smokeTrailFX
    }
	else
    {
		if(IsValid(player.p.DEV_lastDroppedSurvivalWeaponProp))
			player.p.DEV_lastDroppedSurvivalWeaponProp.Destroy()
    }
}

void function CharSelect( entity player)
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
{
	if(!FlowState_PROPHUNT())
	{
	//Char select.
	file.characters = clone GetAllCharacters()
	ItemFlavor PersonajeEscogido = file.characters[FlowState_ChosenCharacter()]
	CharacterSelect_AssignCharacter( ToEHI( player ), PersonajeEscogido )}

	//Dummies
	if (FlowState_DummyOverride()) {
		player.SetBodyModelOverride( $"mdl/humans/class/medium/pilot_medium_generic.rmdl" )
		player.SetArmsModelOverride( $"mdl/humans/class/medium/pilot_medium_generic.rmdl" )
		player.SetSkin(player.GetTeam())
	}

	//Data knife
	player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_2 )
	player.TakeOffhandWeapon( OFFHAND_MELEE )
	player.TakeOffhandWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_2 )
	player.GiveWeapon( "mp_weapon_melee_survival", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
	player.GiveOffhandWeapon( "melee_data_knife", OFFHAND_MELEE, [] )
	if(FlowState_PROPHUNT())
	{
	file.characters = clone GetAllCharacters()
	ItemFlavor PersonajeEscogido = file.characters[RandomInt(9)]
	CharacterSelect_AssignCharacter( ToEHI( player ), PersonajeEscogido )
	TakeAllWeapons(player)
	}
}

// ███████  ██████  ██████  ██████  ███████ ██████   ██████   █████  ██████  ██████
// ██      ██      ██    ██ ██   ██ ██      ██   ██ ██    ██ ██   ██ ██   ██ ██   ██
// ███████ ██      ██    ██ ██████  █████   ██████  ██    ██ ███████ ██████  ██   ██
     // ██ ██      ██    ██ ██   ██ ██      ██   ██ ██    ██ ██   ██ ██   ██ ██   ██
// ███████  ██████  ██████  ██   ██ ███████ ██████   ██████  ██   ██ ██   ██ ██████

void function Message( entity player, string text, string subText = "", float duration = 7.0, string sound = "" )
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
{
	string sendMessage
	for ( int textType = 0 ; textType < 2 ; textType++ )
	{
		sendMessage = textType == 0 ? text : subText

		for ( int i = 0; i < sendMessage.len(); i++ )
		{
			Remote_CallFunction_NonReplay( player, "Dev_BuildClientMessage", textType, sendMessage[i] )
		}
	}
	Remote_CallFunction_NonReplay( player, "Dev_PrintClientMessage", duration )
	if ( sound != "" )
		thread EmitSoundOnEntityOnlyToPlayer( player, player, sound )
}

entity function PlayerWithMostDamage()
//The challenger
{

    int bestDamage = 0
	entity bestPlayer

    foreach(player in GetPlayerArray()) {
        if(!IsValid(player)) continue
        if (int(player.p.playerDamageDealt) > bestDamage) {
            bestDamage = int(player.p.playerDamageDealt)
            bestPlayer = player

        }
    }
    return bestPlayer
}

int function GetDamageOfPlayerWithMostDamage()
//Challenger's score
{
    int bestDamage = 0
    foreach(player in GetPlayerArray()) {
        if(!IsValid(player)) continue
        if (int(player.p.playerDamageDealt) > bestDamage) bestDamage = int(player.p.playerDamageDealt)
    }
    return bestDamage
}

string function PlayerWithMostDamageName()
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)
{
entity player = PlayerWithMostDamage()
if(!IsValid(player)) return "-still nobody-"
string damagechampion = player.GetPlayerName()
return damagechampion
}

entity function GetBestPlayer()
//The champion
{
    int bestScore = 0
	entity bestPlayer

    foreach(player in GetPlayerArray()) {
        if(!IsValid(player)) continue
        if (player.GetPlayerGameStat( PGS_KILLS ) > bestScore) {
            bestScore = player.GetPlayerGameStat( PGS_KILLS )
            bestPlayer = player

        }
    }
    return bestPlayer
}

int function GetBestPlayerScore()
//Champion's score
{
    int bestScore = 0
    foreach(player in GetPlayerArray()) {
        if(!IsValid(player)) continue
        if (player.GetPlayerGameStat( PGS_KILLS ) > bestScore) bestScore = player.GetPlayerGameStat( PGS_KILLS )
    }
    return bestScore
}

string function GetBestPlayerName()
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
{
entity player = GetBestPlayer()
if(!IsValid(player)) return "-still nobody-"
string champion = player.GetPlayerName()
return champion
}

float function getkd(int kills, int deaths)
//By michae\l/#1125 & Retículo Endoplasmático#5955
{
float kd
int floorkd
if(deaths == 0) return kills.tofloat();
kd = kills.tofloat() / deaths.tofloat()
kd = kd*100
floorkd = int(floor(kd+0.5))
kd = (float(floorkd))/100
return kd
}

string function ScoreboardFinal(bool fromConsole = false)
//Este muestra el scoreboard completo
//Thanks marumaru（vesslanG）#3285
{
array<PlayerInfo> playersInfo = []
array<PlayerInfo> spectators = []
        foreach(player in GetPlayerArray())
        {
          PlayerInfo p
          p.name = player.GetPlayerName()
          p.team = player.GetTeam()
					p.score = player.GetPlayerGameStat( PGS_KILLS )
					p.deaths = player.GetPlayerGameStat( PGS_DEATHS )
					p.kd = getkd(p.score,p.deaths)
					p.damage = int(player.p.playerDamageDealt)
					p.lastLatency = int(player.GetLatency()* 1000)

					if (fromConsole && player.IsObserver() && IsAlive(player)) {spectators.append(p)}
					else {playersInfo.append(p)}

        }
        playersInfo.sort(ComparePlayerInfo)
		string msg = ""
		for(int i = 0; i < playersInfo.len(); i++)
	    {
		    PlayerInfo p = playersInfo[i]
            switch(i)
            {
                case 0:
                     msg = msg + "1. " + p.name + ":   " + p.score + " | " + p.deaths + " | " + p.kd + " | " + p.damage + "\n"
					break
                case 1:
                    msg = msg + "2. " + p.name + ":   " + p.score + " | " + p.deaths + " | " + p.kd + " | " + p.damage + "\n"
                    break
                case 2:
                    msg = msg + "3. " + p.name + ":   " + p.score + " | " + p.deaths + " | " + p.kd + " | " + p.damage + "\n"
                    break
                default:
					msg = msg + p.name + ":   " + p.score + " | " + p.deaths + " | " + p.kd + " | " + p.damage + "\n"
                    break
            }
        }

		if (fromConsole && spectators.len() > 0) {
			msg += "\n\nSpectating Players:\n"
			for(int i = 0; i < spectators.len(); i++)
		  {
			    PlayerInfo p = spectators[i]
					msg += p.name + "\n"
			}
		}
	return msg
}

string function ScoreboardFinalPROPHUNT(bool fromConsole = false)
//Este muestra el scoreboard completo
//Thanks marumaru（vesslanG）#3285
{
array<PlayerInfo> playersInfo = []
array<PlayerInfo> spectators = []
        foreach(player in GetPlayerArray())
        {
          PlayerInfo p
          p.name = player.GetPlayerName()
          p.team = player.GetTeam()
					p.score = player.GetPlayerGameStat( PGS_KILLS )
					p.deaths = player.GetPlayerGameStat( PGS_DEATHS )
					p.kd = getkd(p.score,p.deaths)
					p.damage = int(player.p.playerDamageDealt)
					p.lastLatency = int(player.GetLatency()* 1000)

					if (fromConsole && player.IsObserver() && IsAlive(player)) {spectators.append(p)}
					else {playersInfo.append(p)}

        }
        playersInfo.sort(ComparePlayerInfo)
		string msg = ""
		for(int i = 0; i < playersInfo.len(); i++)
	    {
		    PlayerInfo p = playersInfo[i]
            switch(i)
            {
                case 0:
                     msg = msg + "    1. " + p.name + ":   " + p.score + " | " + p.deaths + "\n"
					break
                case 1:
                    msg = msg + "     2. " + p.name + ":   " + p.score + " | " + p.deaths + "\n"
                    break
                case 2:
                    msg = msg + "     3. " + p.name + ":   " + p.score + " | " + p.deaths + "\n"
                    break
                default:
					msg = msg + "     " + p.name + ":   " + p.score + " | " + p.deaths + "\n"
                    break
            }
        }

		if (fromConsole && spectators.len() > 0) {
			msg += "\n\n Players waiting for respawn:\n"
			for(int i = 0; i < spectators.len(); i++)
		  {
			    PlayerInfo p = spectators[i]
					msg += p.name + "\n"
			}
		}
	return msg
}

string function LatencyBoard()
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
{
array<PlayerInfo> playersInfo = []
        foreach(player in GetPlayerArray())
        {
            PlayerInfo p
            p.name = player.GetPlayerName()
			p.score = player.GetPlayerGameStat( PGS_KILLS )
			p.lastLatency = int(player.GetLatency()* 1000) - 40
            playersInfo.append(p)
        }
        playersInfo.sort(ComparePlayerInfo)
		string msg = ""
		for(int i = 0; i < playersInfo.len(); i++)
	    {
		    PlayerInfo p = playersInfo[i]
            switch(i)
            {
                case 0:
                     msg = msg + "1. " + p.name + ":   " + p.lastLatency  + "ms \n"
					break
                case 1:
                    msg = msg + "2. " + p.name + ":   " + p.lastLatency  + "ms \n"
                    break
                case 2:
                    msg = msg + "3. " + p.name + ":   " + p.lastLatency  + "ms \n"
                    break
                default:
					msg = msg + p.name + ":   " + p.lastLatency + "ms \n"
                    break
            }
        }
		return msg
}

int function ComparePlayerInfo(PlayerInfo a, PlayerInfo b)
{
	if(a.score < b.score) return 1;
	else if(a.score > b.score) return -1;
	return 0;
}

void function ResetAllPlayerStats()
{
    foreach(player in GetPlayerArray()) {
        if(!IsValid(player)) continue
        ResetPlayerStats(player)
    }
}

void function ResetPlayerStats(entity player)
{
    player.SetPlayerGameStat( PGS_SCORE, 0 )
    player.SetPlayerGameStat( PGS_DEATHS, 0)
    player.SetPlayerGameStat( PGS_TITAN_KILLS, 0)
    player.SetPlayerGameStat( PGS_KILLS, 0)
    player.SetPlayerGameStat( PGS_PILOT_KILLS, 0)
    player.SetPlayerGameStat( PGS_ASSISTS, 0)
    player.SetPlayerGameStat( PGS_ASSAULT_SCORE, 0)
    player.SetPlayerGameStat( PGS_DEFENSE_SCORE, 0)
    player.SetPlayerGameStat( PGS_ELIMINATED, 0)
}

//  ██████ ██      ██ ███████ ███    ██ ████████      ██████  ██████  ███    ███ ███    ███ ███    ███  █████  ███    ██ ██████  ███████
// ██      ██      ██ ██      ████   ██    ██        ██      ██    ██ ████  ████ ████  ████ ████  ████ ██   ██ ████   ██ ██   ██ ██
// ██      ██      ██ █████   ██ ██  ██    ██        ██      ██    ██ ██ ████ ██ ██ ████ ██ ██ ████ ██ ███████ ██ ██  ██ ██   ██ ███████
// ██      ██      ██ ██      ██  ██ ██    ██        ██      ██    ██ ██  ██  ██ ██  ██  ██ ██  ██  ██ ██   ██ ██  ██ ██ ██   ██      ██
//  ██████ ███████ ██ ███████ ██   ████    ██         ██████  ██████  ██      ██ ██      ██ ██      ██ ██   ██ ██   ████ ██████  ███████

bool function ChatSetBan( entity enforcer ,string playername, bool ban = true)
{
    if(file.mAdmins.find(playername) != -1)
	    return false
    int index = file.mChatBanned.find(playername)
    if(index != -1 && ban)
	    file.mChatBanned.remove(index)
    else if (index == -1 && !ban)
	    file.mChatBanned.append(playername)
    return true
}

bool function IsChatBanned( entity player )
{
    return file.mChatBanned.find(player.GetPlayerName()) != -1
}

bool function ChatGetBanned( entity enforcer)
{
	foreach(string pname in file.mChatBanned)
	{
        printl("[Banned] -> "+ pname)

	}

    return true
}


void function __InitAdmins()
{
	array<string> Split = split( GetCurrentPlaylistVarString("Admins", "" ) , " ")

	foreach(string data in Split)
	{
		string username = strip(data)
		if(username != " " && file.mAdmins.find(username) == -1)
		file.mAdmins.append(username)
	}
}

string function GetOwnerName()
{
    return file.mAdmins[0]
}

bool function IsAdminStr( string playername )
{
    return file.mAdmins.find(playername) != -1
}

bool function IsAdmin( entity player )
{
    return file.mAdmins.find(player.GetPlayerName()) != -1
}

bool function ClientCommand_FlowstateKick(entity player, array<string> args)
{
	if(IsAdmin( player ))
	    return false

	foreach(sPlayer in GetPlayerArray())
    {
		if(sPlayer.GetPlayerName() == args[0])
		{
			#if SERVER
			printl("[Flowstate] -> Kicking " + sPlayer.GetPlayerName() + " from flowstate.")
			ServerCommand( "kick " + sPlayer.GetPlayerName() )
			#endif
			return true
		}
	}
	return false
}

bool function ClientCommand_ChangeMapSky(entity player, array<string> args)
{
	printt("[Flowstate] -> Changing sky color!")
	#if SERVER
	if(!file.mapSkyToggle) {
		SetConVarFloat( "mat_autoexposure_max", 1.0 )
		SetConVarFloat( "mat_autoexposure_max_multiplier", 0.4 )
		SetConVarFloat( "mat_autoexposure_min", 0.1 )
		SetConVarFloat( "mat_autoexposure_min_multiplier", 1.0 )
		SetConVarFloat( "mat_sky_scale", 1.0 )
		SetConVarString( "mat_sky_color", "1.0 1.0 1.0 1.0" )
		SetConVarFloat( "mat_sun_scale", 1.0 )
		SetConVarString( "mat_sun_color", "1.0 1.5 2.0 1.0" )
		file.mapSkyToggle = true}
	else {
		SetConVarToDefault( "mat_autoexposure_max" )
		SetConVarToDefault( "mat_autoexposure_max_multiplier" )
		SetConVarToDefault( "mat_autoexposure_min" )
		SetConVarToDefault( "mat_autoexposure_min_multiplier" )
		SetConVarToDefault( "mat_sky_scale" )
		SetConVarToDefault( "mat_sky_color" )
		SetConVarToDefault( "mat_sun_scale" )
		SetConVarToDefault( "mat_sun_color" )
		file.mapSkyToggle = true
	}
	return true
	#endif
	unreachable
}

bool function ClientCommand_IsthisevenCrashfixtest(entity player, array<string> args)
{
	return true
}


bool function ClientCommand_SpectateEnemies(entity player, array<string> args)
{
    if ( GetGameState() == eGameState.MapVoting || GetGameState() == eGameState.WaitingForPlayers)
        return false

    array<entity> enemiesArray = GetPlayerArray_Alive()
	enemiesArray.fastremovebyvalue( player )
    if ( IsValid( player ) && enemiesArray.len() > 0 )
    {
        entity specTarget = enemiesArray.getrandom()

        if( specTarget.IsObserver())
        {
            printf("error: try again")
            return false
        }

        if( player.GetPlayerNetInt( "spectatorTargetCount" ) > 0)
        {
            player.SetPlayerNetInt( "spectatorTargetCount", 0 )
	        player.SetSpecReplayDelay( 0 )
            player.StopObserverMode()
			if(IsValidPlayer(player))
			player.TakeDamage(player.GetMaxHealth() + 1, null, null, { damageSourceId=damagedef_suicide, scriptType=DF_BYPASS_SHIELD })
            printf("Respawned!")
        }
        else
        {
			player.MakeInvisible()
            player.SetPlayerNetInt( "spectatorTargetCount", enemiesArray.len() )
	        player.SetSpecReplayDelay( Spectator_GetReplayDelay() )
	        player.StartObserverMode( OBS_MODE_IN_EYE )
	        player.SetObserverTarget( specTarget )
            printf("Spectating!")
        }
    }
    else
    {
        print("There is no one to spectate!")
    }
    return true
}

bool function ClientCommand_SpectateSURF(entity player, array<string> args)
{
    if ( GetGameState() == eGameState.MapVoting || GetGameState() == eGameState.WaitingForPlayers)
        return false

    array<entity> playersON = GetPlayerArray_Alive()
	playersON.fastremovebyvalue( player )

    if ( playersON.len() > 1 && IsValid(player))
    {
        entity specTarget = playersON[0]

        if( specTarget.IsObserver())
        {
            printf("error: try again")
            return false
        }

        if( player.GetPlayerNetInt( "spectatorTargetCount" ) > 0)
        {
            player.SetPlayerNetInt( "spectatorTargetCount", 0 )
	        //player.SetSpecReplayDelay( 2 )
            player.StopObserverMode()
			TpPlayerToSpawnPoint(player)
            printf("Respawned!")
        }
        else
        {
			TpPlayerToSpawnPoint(player)
            player.SetPlayerNetInt( "spectatorTargetCount", playersON.len() )
	        player.SetSpecReplayDelay( 2 )
	        player.StartObserverMode( OBS_MODE_IN_EYE )
	        player.SetObserverTarget( specTarget )
            printf("Spectating!")
        }
    }
    else
    {
        print("There is no one to spectate!")
    }
    return true
}

bool function ClientCommand_AdminMsg(entity player, array<string> args)
{
	if(IsAdmin( player )) {
	    string playerName = player.GetPlayerName()
	    string str = ""
	    foreach (s in args)
	    	str += " " + s

        foreach(sPlayer in GetPlayerArray())
        {
            Message( sPlayer, "Admin message", playerName + " says: "  + str, 6)
        }
	} else return false

	return true
}


string function helpMessage()
{
	return "\n\n           CONSOLE COMMANDS:\n\n " +
	"1. 'kill_self': if you get stuck.\n" +
	"2. 'scoreboard': displays scoreboard to user.\n" +
	"3. 'latency': displays ping of all players to user.\n" +
	"4. 'say [MESSAGE]': send a public message! (" + FlowState_ChatCooldown().tostring() + "s global cooldown)\n" +
	"5. 'spectate': spectate enemies!\n" +
	"6. 'commands': display this message again."
}

bool function ClientCommand_Help(entity player, array<string> args)
{
	if(IsValid(player)) {
		if(FlowState_RandomGunsEverydie())
		{
			Message(player, "WELCOME TO FLOWSTATE: FIESTA", helpMessage(), 10)}
		else if (FlowState_Gungame())
		{
			Message(player, "WELCOME TO FLOWSTATE: GUNGAME", helpMessage(), 10)

		} else if (FlowState_PROPHUNT())
		{
			Message(player, "WELCOME TO FLOWSTATE: PROPHUNT", helpMessagePROPHUNT(), 10)
		} else if (FlowState_SURF())
		{
			Message(player, "Apex SURF", "", 5)
		} else{
			Message(player, "WELCOME TO FLOWSTATE: FFA/TDM", helpMessage(), 10)
		}
	}
	return true
}

bool function ClientCommand_ChatBanList(entity player, array<string> args)
{
    if( !IsAdmin( player ) )
	{
		Message(player, "Admin Only Command", "", 3)
		return false
	}

    ChatGetBanned(player)
	return true
}

bool function ClientCommand_ChatBan(entity player, array<string> args)
{
    if( !IsAdmin( player ) )
	{
		Message(player, "Admin Only Command", "", 3)
		return false
	}

	if(args.len() == 0)
	    return false

    if(ChatSetBan( player, args[0] , true))
		Message(player, "BanHammer -> Player [", args[0] + "] is banned from chat", 3)
	else return false

	return true
}

bool function ClientCommand_ChatUnBan(entity player, array<string> args)
{
    if( !IsAdmin( player ) )
	{
		Message(player, "Admin Only Command", "", 3)
		return false
	}

	if(args.len() == 0)
	    return false

    if(ChatSetBan( player, args[0] , false))
		Message(player, "BanHammer -> Player [", args[0] + "] is unbanned from chat", 3)
	else return false

	return true
}

bool function ClientCommand_ClientMsg(entity player, array<string> args)
{
	if (IsChatBanned( player ))
	{
		Message( player, "Trollbox", "YOU ARE BANNED FROM FLOWSTATE GLOBAL MESSAGES.", 5)
		return false
	}

    float cooldown = FlowState_ChatCooldown()
	if( Time() - file.lastTimeChatUsage < cooldown )
		return false

	string str = ""
	foreach (s in args)
		str += " " + s

	string finalChat = player.GetPlayerName() + ": " + str + "\n"

	if(currentChatLine < chatLines)
		currentChat = currentChat + finalChat
	else
		currentChat =  finalChat ; currentChatLine = 0

	currentChatLine++

    if(IsValidPlayer(player))
    {
        foreach(sPlayer in GetPlayerArray())
        {
            Message( sPlayer, "Trollbox", currentChat, 5)
        }
        file.lastTimeChatUsage = Time()
	}
	return true
}

bool function ClientCommand_DispayChatHistory(entity player, array<string> args)
{
    if(IsValidPlayer(player) && IsAdmin( player ))
    {
        foreach(sPlayer in GetPlayerArray())
        {
            Message( sPlayer, "TROLLBOX HISTORY", currentChat, 5)
        }
        file.lastTimeChatUsage = Time()
    }
	return true
}

bool function ClientCommand_ShowLatency(entity player, array<string> args)
{
    try{
    	Message(player,"Latency board", LatencyBoard(), 8)
    }catch(e) {}

    return true
}

bool function ClientCommand_GiveWeapon(entity player, array<string> args)
{
	bool CanGive = GetCurrentPlaylistVarBool("tgive_enabled", true)

    if ( CanGive || !IsAdmin( player ) || args.len() < 2)
		return false

    bool foundMatch = false
	foundMatch = file.whitelistedWeapons.find(args[1]) != -1

    if(file.whitelistedWeapons.find(args[1]) == -1 && file.whitelistedWeapons.len())
	    return false

	entity weapon

    switch(args[0])
    {
        case "p":
        case "primary":
            entity primary = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
            if( IsValid( primary ) ){
				player.TakeWeaponByEntNow( primary )
				weapon = player.GiveWeapon(args[1], WEAPON_INVENTORY_SLOT_PRIMARY_0)
			}
        break
        case "s":
        case "secondary":
            entity secondary = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 )
            if( IsValid( secondary ) ) {
				player.TakeWeaponByEntNow( secondary )
				weapon = player.GiveWeapon(args[1], WEAPON_INVENTORY_SLOT_PRIMARY_1)
			}
        break
        case "t":
        case "tactical":
            entity tactical = player.GetOffhandWeapon( OFFHAND_TACTICAL )
			if( IsValid( tactical ) ) {
				float oldTacticalChargePercent = float( tactical.GetWeaponPrimaryClipCount()) / float(tactical.GetWeaponPrimaryClipCountMax() )
				player.TakeOffhandWeapon( OFFHAND_TACTICAL )

				weapon = player.GiveOffhandWeapon(args[1], OFFHAND_TACTICAL)
				entity newTactical = player.GetOffhandWeapon( OFFHAND_TACTICAL )
				newTactical.SetWeaponPrimaryClipCount( int( newTactical.GetWeaponPrimaryClipCountMax() * oldTacticalChargePercent ) )
			}
        break
        case "u":
        case "ultimate":
            entity ultimate = player.GetOffhandWeapon( OFFHAND_ULTIMATE )
            if( IsValid( ultimate ) )
			{
				player.TakeOffhandWeapon( OFFHAND_ULTIMATE )
				weapon = player.GiveOffhandWeapon(args[1], OFFHAND_ULTIMATE)
			}
        break
    }

    if( args.len() > 2 )
    {
        try {
            weapon.SetMods(args.slice(2, args.len()))
        }
        catch( e2 ) {
            print("invalid mod")
        }
    }
    if( IsValid(weapon) && !weapon.IsWeaponOffhand() )
		player.SetActiveWeaponBySlot(eActiveInventorySlot.mainHand, GetSlotForWeapon(player, weapon))

    return true
}

bool function ClientCommand_NextRound(entity player, array<string> args)
{
    if(IsAdmin( player) && args.len()) {
        if (args[0] == "now")
        {
           file.tdmState = eTDMState.NEXT_ROUND_NOW ; file.mapIndexChanged = false
	       return true
        }

        int mapIndex = int(args[0])
        file.nextMapIndex = (((mapIndex >= 0 ) && (mapIndex < file.locationSettings.len())) ? mapIndex : RandomIntRangeInclusive(0, file.locationSettings.len() - 1))
        file.mapIndexChanged = true

	    if(args.len() > 1){
	    	if (args[1] == "now")
	    	   file.tdmState = eTDMState.NEXT_ROUND_NOW
	    }
	} else return false

	return true
}
bool function ClientCommand_adminnoclip( entity player, array<string> args )
{
	if(!IsValid(player)) return false

	if(IsAdmin( player)) {
		if ( player.IsNoclipping() )
			player.SetPhysics( MOVETYPE_WALK )
		else
			player.SetPhysics( MOVETYPE_NOCLIP )
		return true
	}

	return true
}

bool function ClientCommand_CircleNow(entity player, array<string> args)
{
	if(!IsValid(player)) return false

	if(IsAdmin( player))
		SummonPlayersInACircle(player)

	return true
}

bool function ClientCommand_God(entity player, array<string> args)
{
	if( !IsValid(player) && !IsAdmin(player) ) return false

	player.MakeInvisible()
	MakeInvincible(player)
	HolsterAndDisableWeapons(player)

	return true
}


bool function ClientCommand_UnGod(entity player, array<string> args)
{
	if( !IsValid(player) && !IsAdmin(player) ) return false

	player.MakeVisible()
	ClearInvincible(player)
	EnableOffhandWeapons( player )
	DeployAndEnableWeapons(player)

	return true
}

bool function ClientCommand_Scoreboard(entity player, array<string> args)
{
	float ping = player.GetLatency() * 1000 - 40

	if(IsValid(player)) {
		Message(player,
        "- CURRENT SCOREBOARD - ",
        "\n               CHAMPION: " + GetBestPlayerName() + " / " + GetBestPlayerScore() + " kills.\n" +
        "\n Name:    K  |   D   |   KD   |   Damage dealt\n" +
        ScoreboardFinal(true) + "\n" +
        "\nYour ping: " + ping.tointeger() + "ms.\n" +
        "Hosted by: " + GetOwnerName()
        , 4)
	}
	return true
}

bool function ClientCommand_ScoreboardPROPHUNT(entity player, array<string> args)
{
	float ping = player.GetLatency() * 1000 - 40
    if(IsValid(player))
    {
        Message(player,
        "- PROPHUNT SCOREBOARD - ",
        "Name:    K  |   D   \n" +
        ScoreboardFinalPROPHUNT(true) + "\n" +
        "Your ping: " + ping + "ms. \n" +
        "Hosted by: " + GetOwnerName()
        , 5)
    }

	return true
}

array<entity> function shuffleArray(array<entity> arr)
{
    // O(n) Durstenfeld / Knuth shuffle (https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle)
	int i; int j; entity tmp;

	for (i = arr.len() - 1; i > 0; i--) {
		j = RandomIntRangeInclusive(1, i)
		tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
		}

	return arr
}

bool function ClientCommand_RebalanceTeams(entity player, array<string> args)
{
    if(IsAdmin(player)) {
        int currentTeam = 2
        int numTeams = int(args[0])

        foreach (p in shuffleArray(GetPlayerArray()))
        {
            if (IsValid(p)) {SetTeam(p,TEAM_IMC + 2 + (currentTeam % numTeams))}
                    currentTeam += 1
            Message(p, "TEAMS REBALANCED", "We have now " + numTeams + " teams.", 4)
        }
	} else return false
	unreachable
}


void function CreateAnimatedLegend(asset a, vector pos, vector ang , int solidtype = 0, float size = 1.0)
{
	entity Legend = CreatePropScript(a, pos, ang, solidtype)
	Legend.kv.teamnumber = 99
	Legend.kv.fadedist = 5000
    Legend.kv.renderamt = 255
	Legend.kv.rendermode = 3
	Legend.kv.rendercolor = "255 255 255 255"
	Legend.SetModelScale( size )

	thread AnimationTiming(Legend, 8.0)
}

void function AnimationTiming( entity legend, float cycle )
{
	array<string> animationStrings = ["ACT_MP_MENU_LOBBY_CENTER_IDLE", "ACT_MP_MENU_READYUP_INTRO", "ACT_MP_MENU_LOBBY_SELECT_IDLE", "ACT_VICTORY_DANCE"]
	while( IsValid(legend) )
	{
		legend.SetCycle( cycle )
		legend.Anim_Play( animationStrings[RandomInt(animationStrings.len())] )
		WaittillAnimDone(legend)
	}
}
