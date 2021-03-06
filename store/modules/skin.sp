#define Module_Skin

#define Model_ZE_Newbee "models/player/custom_player/legacy/tm_leet_variant_classic.mdl"

enum PlayerSkin
{
    String:szModel[PLATFORM_MAX_PATH],
    String:szArms[PLATFORM_MAX_PATH],
    String:szSound[PLATFORM_MAX_PATH],
    iLevel,
    iTeam
}

PlayerSkin g_ePlayerSkins[STORE_MAX_ITEMS][PlayerSkin];

int g_iPlayerSkins = 0;
int g_iSkinLevel[MAXPLAYERS+1];
int g_iPreviewTimes[MAXPLAYERS+1];
int g_iPreviewModel[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
int g_iCameraRef[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
bool g_bSpecJoinPending[MAXPLAYERS+1];
char g_szDeathVoice[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_szSkinModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];
ConVar spec_freeze_time;
ConVar mp_round_restart_delay;
ConVar sv_disablefreezecam;
ConVar spec_replay_enable;

Handle g_tKillPreview[MAXPLAYERS+1];

void Skin_OnPluginStart()
{
    AddNormalSoundHook(Hook_NormalSound);

    Store_RegisterHandler("playerskin", PlayerSkins_OnMapStart, PlayerSkins_Reset, PlayerSkins_Config, PlayerSkins_Equip, PlayerSkins_Remove, true);

    RegAdminCmd("sm_arms", Command_Arms, ADMFLAG_ROOT, "Fixed Player Arms");

    //DEATH CAMERA CCVAR
    spec_freeze_time = FindConVar("spec_freeze_time");
    HookConVarChange(spec_freeze_time, Skin_OnConVarChanged);
    SetConVarString(spec_freeze_time, "-1.0", true);

    sv_disablefreezecam = FindConVar("sv_disablefreezecam");
    HookConVarChange(sv_disablefreezecam, Skin_OnConVarChanged);
    SetConVarString(sv_disablefreezecam, "1", true);

    mp_round_restart_delay = FindConVar("mp_round_restart_delay");
    HookConVarChange(mp_round_restart_delay, Skin_OnConVarChanged);
    SetConVarString(mp_round_restart_delay, "12", true);
    
    spec_replay_enable = FindConVar("spec_replay_enable");
    HookConVarChange(spec_replay_enable, Skin_OnConVarChanged);
    SetConVarString(spec_replay_enable, "0", true);

    g_ArraySkin = CreateArray(ByteCountToCells(256));
}

public void Skin_OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if(convar == spec_freeze_time)
        SetConVarString(spec_freeze_time, "-1.0", true);

    if(convar == sv_disablefreezecam)
        SetConVarString(sv_disablefreezecam, "1", true);    

    if(convar == mp_round_restart_delay)
        SetConVarString(mp_round_restart_delay, "12", true);
    
    if(convar == spec_replay_enable)
        SetConVarString(spec_replay_enable, "0", true);
}

void Skin_OnClientDisconnect(int client)
{
    if(g_tKillPreview[client] != null)
        TriggerTimer(g_tKillPreview[client], false);

    if(g_iCameraRef[client] != INVALID_ENT_REFERENCE)
        CreateTimer(0.0, Timer_ClearCamera, client);

    if(g_bSpecJoinPending[client])
        g_bSpecJoinPending[client] = false;
}

public Action Command_Arms(int client, int args)
{
    if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Handled;

#if defined GM_ZE    
    if(g_iClientTeam[client] == 2)
        return Plugin_Handled;
#endif

    Store_PreSetClientModel(client);

    return Plugin_Handled;
}

public bool PlayerSkins_Config(Handle kv, int itemid)
{
    Store_SetDataIndex(itemid, g_iPlayerSkins);
    
    KvGetString(kv, "model", g_ePlayerSkins[g_iPlayerSkins][szModel], PLATFORM_MAX_PATH);
    KvGetString(kv, "arms", g_ePlayerSkins[g_iPlayerSkins][szArms], PLATFORM_MAX_PATH);
    KvGetString(kv, "sound", g_ePlayerSkins[g_iPlayerSkins][szSound], PLATFORM_MAX_PATH);
    
    g_ePlayerSkins[g_iPlayerSkins][iLevel] = KvGetNum(kv, "lvls", 0)+1;

#if defined Global_Skin
    g_ePlayerSkins[g_iPlayerSkins][iTeam] = 4;
#else
    g_ePlayerSkins[g_iPlayerSkins][iTeam] = KvGetNum(kv, "team");
#endif

    if(FileExists(g_ePlayerSkins[g_iPlayerSkins][szModel], true))
    {
        ++g_iPlayerSkins;
        return true;
    }

    return false;
}

public void PlayerSkins_OnMapStart()
{
    char szPath[PLATFORM_MAX_PATH], szPathStar[PLATFORM_MAX_PATH];
    for(int i = 0; i < g_iPlayerSkins; ++i)
    {
        PrecacheModel2(g_ePlayerSkins[i][szModel], true);
        Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i][szModel]);

        if(g_ePlayerSkins[i][szArms][0] != 0)
        {
            PrecacheModel2(g_ePlayerSkins[i][szArms], true);
            Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i][szArms]);
        }

        if(g_ePlayerSkins[i][szSound][0] != 0)
        {
            Format(szPath, 256, "sound/%s", g_ePlayerSkins[i][szSound]);
            if(FileExists(szPath, true))
            {
                Format(szPathStar, 256, "*%s", g_ePlayerSkins[i][szSound]);
                AddToStringTable(FindStringTable("soundprecache"), szPathStar);
                Downloader_AddFileToDownloadsTable(szPath);
            }
        }
    }

    //PrecacheDefaultModel();
    
    PrecacheModel2("models/blackout.mdl", true);

#if defined GM_ZE
    if(FileExists(Model_ZE_Newbee))
    {
        PrecacheModel2(Model_ZE_Newbee, true);
        Downloader_AddFileToDownloadsTable(Model_ZE_Newbee);
    }
#endif
}

public void PlayerSkins_Reset()
{
    g_iPlayerSkins = 0;
}

public int PlayerSkins_Equip(int client, int id)
{
    if(IsClientInGame(client) && IsPlayerAlive(client))
        tPrintToChat(client, "%T", "PlayerSkins Settings Changed", client);

    return g_ePlayerSkins[Store_GetDataIndex(id)][iTeam]-2;
}

public int PlayerSkins_Remove(int client, int id)
{
    if(IsClientInGame(client))
        tPrintToChat(client, "%T", "PlayerSkins Settings Changed", client);

    return g_ePlayerSkins[Store_GetDataIndex(id)][iTeam]-2;
}

void Store_PreSetClientModel(int client)
{
    strcopy(g_szSkinModel[client], 256, "default");

#if defined Global_Skin
    int m_iEquipped = Store_GetEquippedItem(client, "playerskin", 2);
#else
    int m_iEquipped = Store_GetEquippedItem(client, "playerskin", g_iClientTeam[client]-2);
#endif

    if(m_iEquipped >= 0)
    {
        //SetDefaultSkin(client, g_iClientTeam[client]);

        int m_iData = Store_GetDataIndex(m_iEquipped);

        //if(!StrEqual(g_ePlayerSkins[m_iData][szArms], "null"))
        //    SetEntPropString(client, Prop_Send, "m_szArmsModel", g_ePlayerSkins[m_iData][szArms]);

        CreateTimer(0.02, Timer_SetClientModel, client | (m_iData << 7), TIMER_FLAG_NO_MAPCHANGE);

        if(g_ePlayerSkins[m_iData][szSound][0] != 0)
            Format(g_szDeathVoice[client], 256, "*%s", g_ePlayerSkins[m_iData][szSound]);
    }
#if defined GM_ZE
    else
    {
        CreateTimer(0.02, Store_SetClientModelZE, client, TIMER_FLAG_NO_MAPCHANGE);
    }
#endif
}

void Store_SetClientModel(int client, int m_iData)
{
    if(!IsClientInGame(client) || !IsPlayerAlive(client))
        return;
    
#if defined GM_ZE
    if(g_iClientTeam[client] == 2)
    {
        strcopy(g_szSkinModel[client], 256, "zombie");
        return;
    }
#endif

    SetEntityModel(client, g_ePlayerSkins[m_iData][szModel]);
    
    if(!StrEqual(g_ePlayerSkins[m_iData][szArms], "null"))
        SetEntPropString(client, Prop_Send, "m_szArmsModel", g_ePlayerSkins[m_iData][szArms]);
    
    strcopy(g_szSkinModel[client], 256, g_ePlayerSkins[m_iData][szModel]);
    
    g_iSkinLevel[client] = g_ePlayerSkins[m_iData][iLevel];

#if defined Module_Hats
    Store_SetClientHat(client);
#endif
}

public Action Timer_SetClientModel(Handle timer, int Value)
{
    Store_SetClientModel(Value & 0x7f, Value >> 7);

    return Plugin_Stop;
}

#if defined GM_ZE
public Action Store_SetClientModelZE(Handle timer, int client)
{
    if(!IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    if(g_iClientTeam[client] == 2)
    {
        strcopy(g_szSkinModel[client], 256, "zombie");
        return Plugin_Stop;
    }

    strcopy(g_szSkinModel[client], 256, "default");
    SetEntityModel(client, Model_ZE_Newbee);

#if defined Module_Hats
    Store_SetClientHat(client);
#endif

    return Plugin_Stop;
}
#endif

public Action Hook_NormalSound(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &client, int &channel, float &volume, int &level, int &pitch, int &flags)
{
    if(channel != SNDCHAN_VOICE || !IsValidClient(client))
        return Plugin_Continue;
    
#if defined GM_ZE
    if(g_iClientTeam[client] == 2)
        return Plugin_Continue;
#endif

    if(g_szDeathVoice[client][0] == '\0')
        return Plugin_Continue;

    if  ( 
            StrEqual(sample, "~player/death1.wav", false)||
            StrEqual(sample, "~player/death2.wav", false)||
            StrEqual(sample, "~player/death3.wav", false)||
            StrEqual(sample, "~player/death4.wav", false)||
            StrEqual(sample, "~player/death5.wav", false)||
            StrEqual(sample, "~player/death6.wav", false)
        )
        {
            strcopy(sample, 128, g_szDeathVoice[client]);
            volume = 1.0;
            return Plugin_Changed;
        }

    return Plugin_Continue;
}

public Action Timer_RemoveSpeaker(Handle timer, int iRef)
{
    int entity = EntRefToEntIndex(iRef);
    if(IsValidEdict(entity))
        AcceptEntityInput(entity, "Kill");

    return Plugin_Stop;
}

void Store_PreviewSkin(int client, int itemid)
{
    if(g_tKillPreview[client] != null)
        TriggerTimer(g_tKillPreview[client], false);

    int m_iViewModel = CreateEntityByName("prop_dynamic_override"); //prop_physics_multiplayer
    char m_szTargetName[32];
    Format(m_szTargetName, 32, "Store_Preview_%d", m_iViewModel);
    DispatchKeyValue(m_iViewModel, "targetname", m_szTargetName);
    DispatchKeyValue(m_iViewModel, "spawnflags", "64");
    DispatchKeyValue(m_iViewModel, "model", g_ePlayerSkins[g_eItems[itemid][iData]][szModel]);
    DispatchKeyValue(m_iViewModel, "rendermode", "0");
    DispatchKeyValue(m_iViewModel, "renderfx", "0");
    DispatchKeyValue(m_iViewModel, "rendercolor", "255 255 255");
    DispatchKeyValue(m_iViewModel, "renderamt", "255");
    DispatchKeyValue(m_iViewModel, "solid", "0");
    
    DispatchSpawn(m_iViewModel);
    
    SetEntProp(m_iViewModel, Prop_Send, "m_CollisionGroup", 11);

    AcceptEntityInput(m_iViewModel, "Enable");

    int offset = GetEntSendPropOffs(m_iViewModel, "m_clrGlow");
    SetEntProp(m_iViewModel, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(m_iViewModel, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(m_iViewModel, Prop_Send, "m_flGlowMaxDist", 2000.0);

    //Miku Green
    SetEntData(m_iViewModel, offset    ,  57, _, true);
    SetEntData(m_iViewModel, offset + 1, 197, _, true);
    SetEntData(m_iViewModel, offset + 2, 187, _, true);
    SetEntData(m_iViewModel, offset + 3, 255, _, true);

    float m_fOrigin[3], m_fAngles[3], m_fRadians[2], m_fPosition[3];

    GetClientAbsOrigin(client, m_fOrigin);
    GetClientAbsAngles(client, m_fAngles);

    m_fRadians[0] = DegToRad(m_fAngles[0]);
    m_fRadians[1] = DegToRad(m_fAngles[1]);

    m_fPosition[0] = m_fOrigin[0] + 64 * Cosine(m_fRadians[0]) * Cosine(m_fRadians[1]);
    m_fPosition[1] = m_fOrigin[1] + 64 * Cosine(m_fRadians[0]) * Sine(m_fRadians[1]);
    m_fPosition[2] = m_fOrigin[2] + 4 * Sine(m_fRadians[0]);
    
    m_fAngles[0] *= -1.0;
    m_fAngles[1] *= -1.0;

    TeleportEntity(m_iViewModel, m_fPosition, m_fAngles, NULL_VECTOR);
    
    g_iPreviewTimes[client] = GetTime()+90;
    g_iPreviewModel[client] = EntIndexToEntRef(m_iViewModel);

    SDKHook(m_iViewModel, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

    g_tKillPreview[client] = CreateTimer(45.0, Timer_KillPreview, client);

    tPrintToChat(client, "%T", "Chat Preview", client);
}

public Action Hook_SetTransmit_Preview(int ent, int client)
{
    if(g_iPreviewModel[client] == INVALID_ENT_REFERENCE)
        return Plugin_Handled;
    
    if(ent == EntRefToEntIndex(g_iPreviewModel[client]))
        return Plugin_Continue;

    return Plugin_Handled;
}

public Action Timer_KillPreview(Handle timer, int client)
{
    g_tKillPreview[client] = null;

    if(g_iPreviewModel[client] != INVALID_ENT_REFERENCE)
    {
        int entity = EntRefToEntIndex(g_iPreviewModel[client]);

        if(IsValidEdict(entity))
        {
            SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
            AcceptEntityInput(entity, "Kill");
        }
    }
    g_iPreviewModel[client] = INVALID_ENT_REFERENCE;

    return Plugin_Stop;
}

public void FirstPersonDeathCamera(int client)
{
#if !defined GM_TT
    if(!IsClientInGame(client) || g_iClientTeam[client] < 2 || IsPlayerAlive(client))
        return;


    int m_iRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");

    if(m_iRagdoll < 0)
        return;

    SpawnCamAndAttach(client, m_iRagdoll);
#endif
}

#if !defined GM_TT
bool SpawnCamAndAttach(int client, int ragdoll)
{
    char m_szTargetName[32]; 
    Format(m_szTargetName, 32, "ragdoll%d", client);
    DispatchKeyValue(ragdoll, "targetname", m_szTargetName);

    int iEntity = CreateEntityByName("prop_dynamic");
    if(iEntity == -1)
        return false;

    char m_szCamera[32]; 
    Format(m_szCamera, 32, "ragdollCam%d", iEntity);

    DispatchKeyValue(iEntity, "targetname", m_szCamera);
    DispatchKeyValue(iEntity, "parentname", m_szTargetName);
    DispatchKeyValue(iEntity, "model",      "models/blackout.mdl");
    DispatchKeyValue(iEntity, "solid",      "0");
    DispatchKeyValue(iEntity, "rendermode", "10"); // dont render
    DispatchKeyValue(iEntity, "disableshadows", "1"); // no shadows

    float m_fAngles[3]; 
    GetClientEyeAngles(client, m_fAngles);
    
    char m_szCamAngles[64];
    Format(m_szCamAngles, 64, "%f %f %f", m_fAngles[0], m_fAngles[1], m_fAngles[2]);

    DispatchKeyValue(iEntity, "angles", m_szCamAngles);

    SetEntityModel(iEntity, "models/blackout.mdl");
    DispatchSpawn(iEntity);

    SetVariantString(m_szTargetName);
    AcceptEntityInput(iEntity, "SetParent", iEntity, iEntity, 0);

    SetVariantString("facemask");
    AcceptEntityInput(iEntity, "SetParentAttachment", iEntity, iEntity, 0);

    AcceptEntityInput(iEntity, "TurnOn");

    SetClientViewEntity(client, iEntity);
    g_iCameraRef[client] = EntIndexToEntRef(iEntity);
    
    FadeScreenBlack(client);

    CreateTimer(10.0, Timer_ClearCamera, client);

    //SetEntPropEnt(client, Prop_Send, "m_hRagdoll", iEntity);

    return true;
}
#endif

public Action Timer_ClearCamera(Handle timer, int client)
{
    if(g_iCameraRef[client] != INVALID_ENT_REFERENCE)
    {
        int entity = EntRefToEntIndex(g_iCameraRef[client]);

        if(IsValidEdict(entity))
        {
            AcceptEntityInput(entity, "Kill");
        }

        g_iCameraRef[client] = INVALID_ENT_REFERENCE;
    }

    if(IsClientInGame(client))
    {
        SetClientViewEntity(client, client);
#if !defined GM_TT
        FadeScreenWhite(client);
#endif
    }

    return Plugin_Stop;
}

void AttemptState(int client, bool spec)
{
    char client_specmode[10];
    GetClientInfo(client, "cl_spec_mode", client_specmode, 9);
    if(StringToInt(client_specmode) <= 4)
    {
        g_bSpecJoinPending[client] = spec;
        ClientCommand(client, "cl_spec_mode 6");
    }
}

#if !defined GM_TT

#define FFADE_IN        0x0001        // Just here so we don't pass 0 into the function
#define FFADE_OUT       0x0002        // Fade out (not in)
#define FFADE_MODULATE  0x0004        // Modulate (don't blend)
#define FFADE_STAYOUT   0x0008        // ignores the duration, stays faded out until new ScreenFade message received
#define FFADE_PURGE     0x0010        // Purges all other fades, replacing them with this one

void FadeScreenBlack(int client)
{
    Handle pb = StartMessageOne("Fade", client);
    PbSetInt(pb, "duration", 4096);
    PbSetInt(pb, "hold_time", 0);
    PbSetInt(pb, "flags", FFADE_OUT|FFADE_PURGE|FFADE_STAYOUT);
    PbSetColor(pb, "clr", {0, 0, 0, 255});
    EndMessage();
}

void FadeScreenWhite(int client)
{
    Handle pb = StartMessageOne("Fade", client);
    PbSetInt(pb, "duration", 1536);
    PbSetInt(pb, "hold_time", 1536);
    PbSetInt(pb, "flags", FFADE_IN|FFADE_PURGE);
    PbSetColor(pb, "clr", {0, 0, 0, 0});
    EndMessage();
}
#endif

#if defined GM_ZE
public void CG_OnRoundEnd(int winner)
{
    for(int client = 1; client <= MaxClients; ++client)
        g_iClientTeam[client] = 3;
}
#endif