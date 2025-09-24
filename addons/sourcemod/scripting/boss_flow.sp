#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <left4dhooks>


public Plugin myinfo = {
    name        = "BossFlow",
    author      = "TouchMe",
    description = "Manipulating boss spawns",
    version     = "build_0002",
    url         = "https://github.com/TouchMe-Inc/l4d2_boss_flow"
}


#define MAX_MAP_NAME_LENGTH 32

#define MIN_FLOW 1
#define MAX_FLOW 100
#define CVAR_MIN_FLOW (RoundToCeil(GetConVarFloat(g_cvVsBossFlowMin) * 100.0))
#define CVAR_MAX_FLOW (RoundToFloor(GetConVarFloat(g_cvVsBossFlowMax) * 100.0))

enum Boss
{
    Boss_Tank,
    Boss_Witch,
    BOSS_SIZE
}

char g_szMapName[MAX_MAP_NAME_LENGTH];

Handle g_hStaticBossMaps[BOSS_SIZE];
Handle g_hBannedBossFlow[BOSS_SIZE];

Handle
    g_hStaticTankMaps = null,
    g_hStaticWitchMaps = null
;

ConVar
    g_cvAttemptsFindMaxInterval = null,
    g_cvTankSpawnAllow = null,
    g_cvWitchSpawnAllow = null,
    g_cvVsBossFlowMin = null,
    g_cvVsBossFlowMax = null
;


/**
 * Called before OnPluginStart.
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] szErr, int iErrLen)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(szErr, iErrLen, "Plugin only supports Left 4 Dead 2");
        return APLRes_SilentFailure;
    }

    CreateNative("IsBossSpawnAllowed", Native_IsBossSpawnAllowed);
    CreateNative("IsMapWithStaticBossSpawn", Native_IsMapWithStaticBoss);
    CreateNative("IsMapWithStaticBoss", Native_IsMapWithStaticBoss);
    CreateNative("IsAvaibleBossFlow", Native_IsAvaibleBossFlow);
    CreateNative("SetBossFlow", Native_SetBossFlow);
    CreateNative("GetBossFlow", Native_GetBossFlow);

    RegPluginLibrary("boss_flow");

    return APLRes_Success;
}

public int Native_IsBossSpawnAllowed(Handle plugin, int numParams)
{
    Boss boss = view_as<Boss>(GetNativeCell(1));

    switch (boss)
    {
        case Boss_Tank: return GetConVarBool(g_cvTankSpawnAllow);
        case Boss_Witch: return GetConVarBool(g_cvWitchSpawnAllow);
    }

    return 0;
}

public int Native_IsMapWithStaticBoss(Handle plugin, int numParams)
{
    Boss boss = view_as<Boss>(GetNativeCell(1));

    return IsMapWithStaticBoss(boss);
}

public int Native_IsAvaibleBossFlow(Handle plugin, int numParams)
{
    Boss boss = view_as<Boss>(GetNativeCell(1));
    int iFlow = GetNativeCell(2);

    if (!IsValidFlow(iFlow)) {
        return -2;
    }

    if (!IsValidBossFlow(iFlow)) {
        return -1;
    }

    return IsAvaibleBossFlow(boss, iFlow);
}

public int Native_SetBossFlow(Handle plugin, int numParams)
{
    Boss boss = view_as<Boss>(GetNativeCell(1));
    int iFlow = GetNativeCell(2);

    switch (boss)
    {
        case Boss_Tank: SetTankFlow(iFlow);
        case Boss_Witch: SetWitchFlow(iFlow);
    }

    return 1;
}

public int Native_GetBossFlow(Handle plugin, int numParams)
{
    Boss boss = view_as<Boss>(GetNativeCell(1));
    int iRound = InSecondHalfOfRound() ? 1 : 0;

    switch (boss)
    {
        case Boss_Tank: return RoundToNearest(L4D2Direct_GetVSTankFlowPercent(iRound) * 100.0);
        case Boss_Witch: return RoundToNearest(L4D2Direct_GetVSWitchFlowPercent(iRound) * 100.0);
    }

    return -1;
}

public void OnPluginStart()
{
    g_hStaticBossMaps[Boss_Witch] = CreateTrie();
    g_hStaticBossMaps[Boss_Tank] = CreateTrie();
    g_hBannedBossFlow[Boss_Witch] = CreateTrie();
    g_hBannedBossFlow[Boss_Tank] = CreateTrie();

    g_cvVsBossFlowMin = FindConVar("versus_boss_flow_min");
    g_cvVsBossFlowMax = FindConVar("versus_boss_flow_max");

    g_cvAttemptsFindMaxInterval = CreateConVar("sm_boss_flow_attempts_find_max_interval", "2", "Number of attempts to find the greatest distance", _, true, 1.0);
    g_cvTankSpawnAllow = CreateConVar("sm_tank_spawn_allow", "1", "Allow tank spawn", _, true, 0.0, true, 1.0);
    g_cvWitchSpawnAllow = CreateConVar("sm_witch_spawn_allow", "1", "Allow witch spawn", _, true, 0.0, true, 1.0);

    RegServerCmd("static_boss_map", Cmd_StaticBossMap, "static_boss_map <boss> <map>");
    RegServerCmd("reset_static_maps", Cmd_ResetStaticMaps);

    RegServerCmd("ban_boss_flow", Cmd_BanBossFlow, "ban_boss_flow <boss> <map> <start> <end>");
    RegServerCmd("reset_banned_flow", Cmd_ResetBannedFlow);
}

public void OnMapStart()
{
    GetCurrentMap(g_szMapName, sizeof(g_szMapName));

    int iTankFlow = GetRandomTankFlow();
    int iWitchFlow = GetRandomWitchFlow();

    int iAttemptsFindMaxInterval = GetConVarInt(g_cvAttemptsFindMaxInterval);
    int iMaxInterval = abs(iTankFlow - iWitchFlow);

    for (int iTry = 1; iTry <= iAttemptsFindMaxInterval; iTry ++)
    {
        int iTempTankFlow = GetRandomTankFlow();
        int iTempWitchFlow = GetRandomWitchFlow();
        int iTempMaxInterval = abs(iTempTankFlow - iTempWitchFlow);

        if (iTempMaxInterval <= iMaxInterval) {
            continue;
        }

        iTankFlow = iTempTankFlow;
        iWitchFlow = iTempWitchFlow;
        iMaxInterval = iTempMaxInterval;
    }

    SetTankFlow(IsMapWithStaticBoss(Boss_Tank) ? 0 : iTankFlow);
    SetWitchFlow(IsMapWithStaticBoss(Boss_Witch) ? 0 : iWitchFlow);
}

public Action L4D_OnSpawnTank(const float vPos[3], const float vAng[3]) {
    return GetConVarBool(g_cvTankSpawnAllow) ? Plugin_Continue : Plugin_Handled;
}

public Action L4D_OnSpawnWitch(const float vPos[3], const float vAng[3]) {
    return GetConVarBool(g_cvWitchSpawnAllow) ? Plugin_Continue : Plugin_Handled;
}

public Action L4D2_OnSpawnWitchBride(const float vPos[3], const float vAng[3]) {
    return GetConVarBool(g_cvWitchSpawnAllow) ? Plugin_Continue : Plugin_Handled;
}

Action Cmd_StaticBossMap(int args)
{
    char szBoss[8];
    GetCmdArg(1, szBoss, sizeof szBoss);

    char szMapName[MAX_MAP_NAME_LENGTH];
    GetCmdArg(2, szMapName, sizeof(szMapName));

    if (StrEqual(szBoss, "tank", false)) {
        SetTrieValue(g_hStaticBossMaps[Boss_Tank], szMapName, true);
    } else if (StrEqual(szBoss, "witch", false)) {
        SetTrieValue(g_hStaticBossMaps[Boss_Witch], szMapName, true);
    }

    return Plugin_Handled;
}

Action Cmd_ResetStaticMaps(int args)
{
    ClearTrie(g_hStaticBossMaps[Boss_Tank]);
    ClearTrie(g_hStaticBossMaps[Boss_Witch]);

    return Plugin_Handled;
}

Action Cmd_BanBossFlow(int args)
{
    char szBoss[8];
    GetCmdArg(1, szBoss, sizeof szBoss);

    Boss boss;

    if (StrEqual(szBoss, "tank", false)) {
        boss = Boss_Tank;
    } else if (StrEqual(szBoss, "witch", false)) {
        boss = Boss_Witch;
    } else {
        return Plugin_Handled;
    }

    char szMapName[MAX_MAP_NAME_LENGTH];
    GetCmdArg(2, szMapName, sizeof(szMapName));

    char szFlowStart[4];
    GetCmdArg(3, szFlowStart, sizeof(szFlowStart));

    char szFlowEnd[4];
    GetCmdArg(4, szFlowEnd, sizeof(szFlowEnd));

    int iFlowStart = StringToInt(szFlowStart);
    int iFlowEnd = StringToInt(szFlowEnd);

    if (!IsValidFlow(iFlowStart) || !IsValidFlow(iFlowEnd)) {
        return Plugin_Handled;
    }

    bool bBannedFlow[MAX_FLOW];
    GetTrieArray(g_hBannedBossFlow[boss], szMapName, bBannedFlow, sizeof bBannedFlow);

    for (int iFlow = iFlowStart; iFlow <= iFlowEnd; iFlow ++)
    {
        bBannedFlow[iFlow - 1] = true;
    }

    SetTrieArray(g_hBannedBossFlow[boss], szMapName, bBannedFlow, sizeof bBannedFlow);
    
    return Plugin_Handled;
}

Action Cmd_ResetBannedFlow(int args)
{
    ClearTrie(g_hStaticWitchMaps);
    ClearTrie(g_hStaticTankMaps);

    return Plugin_Handled;
}

bool IsAvaibleBossFlow(Boss boss, int iFlow)
{
    bool bBannedFlow[MAX_FLOW];
    if (!GetTrieArray(g_hBannedBossFlow[boss], g_szMapName, bBannedFlow, sizeof bBannedFlow)) {
        return true;
    }

    return bBannedFlow[iFlow - 1] == false;
}

bool IsValidFlow(int iFlow) {
    return (iFlow >= MIN_FLOW && iFlow <= MAX_FLOW);
}

bool IsValidBossFlow(int iFlow) {
    return (iFlow >= CVAR_MIN_FLOW && iFlow <= CVAR_MAX_FLOW);
}

int GetRandomTankFlow()
{
    Handle hValidTankFlow = CreateArray();

    int iTankFlow = 0;
    int iMinFlow = CVAR_MIN_FLOW;
    int iMaxFlow = CVAR_MAX_FLOW;

    for (int iFlow = iMinFlow; iFlow <= iMaxFlow; iFlow ++)
    {
        if (!IsAvaibleBossFlow(Boss_Tank, iFlow)) {
            continue;
        }

        PushArrayCell(hValidTankFlow, iFlow);
    }

    int iArraySize = GetArraySize(hValidTankFlow);

    if (iArraySize > 0) {
        iTankFlow = GetArrayCell(hValidTankFlow, GetRandomInt(0, iArraySize - 1));
    }

    CloseHandle(hValidTankFlow);

    return iTankFlow;
}

int GetRandomWitchFlow()
{
    int iWitchFlow = 0;

    Handle hValidWitchFlow = CreateArray();

    int iMinFlow = CVAR_MIN_FLOW;
    int iMaxFlow = CVAR_MAX_FLOW;

    for (int iFlow = iMinFlow; iFlow < iMaxFlow; iFlow ++)
    {
        if (!IsAvaibleBossFlow(Boss_Witch, iFlow)) {
            continue;
        }

        PushArrayCell(hValidWitchFlow, iFlow);
    }

    int iArraySize = GetArraySize(hValidWitchFlow);

    if (iArraySize > 0) {
        iWitchFlow = GetArrayCell(hValidWitchFlow, GetRandomInt(0, iArraySize - 1));
    }

    CloseHandle(hValidWitchFlow);

    return iWitchFlow;
}

bool IsMapWithStaticBoss(Boss boss)
{
    bool dummy;

    switch (boss)
    {
        case Boss_Tank: return GetTrieValue(g_hStaticBossMaps[boss], g_szMapName, dummy);
        case Boss_Witch: return GetTrieValue(g_hStaticBossMaps[boss], g_szMapName, dummy);
    }

    return false;
}

void SetTankFlow(int iFlow)
{
    if (iFlow == 0)
    {
        L4D2Direct_SetVSTankFlowPercent(0, 0.0);
        L4D2Direct_SetVSTankFlowPercent(1, 0.0);
        L4D2Direct_SetVSTankToSpawnThisRound(0, false);
        L4D2Direct_SetVSTankToSpawnThisRound(1, false);
    }

    else
    {
        float fPersent = float(iFlow) / 100.0;
        L4D2Direct_SetVSTankFlowPercent(0, fPersent);
        L4D2Direct_SetVSTankFlowPercent(1, fPersent);
        L4D2Direct_SetVSTankToSpawnThisRound(0, true);
        L4D2Direct_SetVSTankToSpawnThisRound(1, true);
    }
}

void SetWitchFlow(int iFlow)
{
    if (iFlow == 0)
    {
        L4D2Direct_SetVSWitchFlowPercent(0, 0.0);
        L4D2Direct_SetVSWitchFlowPercent(1, 0.0);
        L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
        L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
    }

    else
    {
        float fPersent = float(iFlow) / 100.0;
        L4D2Direct_SetVSWitchFlowPercent(0, fPersent);
        L4D2Direct_SetVSWitchFlowPercent(1, fPersent);
        L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
        L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
    }
}

/**
 * Checks if the current round is the second.
 *
 * @return                  Returns true if is second round, otherwise false.
 */
bool InSecondHalfOfRound() {
    return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

int abs(int value) {
    return (value < 0) ? -value : value;
}
