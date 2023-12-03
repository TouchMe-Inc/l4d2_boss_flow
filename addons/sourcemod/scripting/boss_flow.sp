#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <left4dhooks>


public Plugin myinfo = {
    name        = "BossFlow",
    author      = "TouchMe",
    description = "Manipulating boss spawns",
    version     = "build_0001",
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

bool g_bAvaibleBossFlow[BOSS_SIZE][MAX_FLOW];

Handle
    g_hStaticTankMaps = null,
    g_hStaticWitchMaps = null
;

ConVar
    g_cvPathToDir = null,
    g_cvAttemptsFindMaxInterval = null,
    g_cvTankSpawnAllow = null,
    g_cvWitchSpawnAllow = null,
    g_cvVsBossFlowMin = null,
    g_cvVsBossFlowMax = null
;


/**
 * Called before OnPluginStart.
 *
 * @param myself      Handle to the plugin
 * @param bLate       Whether or not the plugin was loaded "late" (after map load)
 * @param sErr        Error message buffer in case load failed
 * @param iErrLen     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
        return APLRes_SilentFailure;
    }

    CreateNative("IsBossSpawnAllowed", Native_IsBossSpawnAllowed);
    CreateNative("IsMapWithStaticBossSpawn", Native_IsMapWithStaticBossSpawn);
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

public int Native_IsMapWithStaticBossSpawn(Handle plugin, int numParams)
{
    Boss boss = view_as<Boss>(GetNativeCell(1));

    return IsMapWithStaticBossSpawn(boss, g_szMapName);
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
    g_hStaticTankMaps = CreateTrie();
    g_hStaticWitchMaps = CreateTrie();

    g_cvVsBossFlowMin = FindConVar("versus_boss_flow_min");
    g_cvVsBossFlowMax = FindConVar("versus_boss_flow_max");

    g_cvPathToDir = CreateConVar("sm_boss_flow_path_to_dir", "addons/sourcemod/configs/boss_flow");
    g_cvAttemptsFindMaxInterval = CreateConVar("sm_boss_flow_attempts_find_max_interval", "2", "Number of attempts to find the greatest distance", _, true, 1.0);
    g_cvTankSpawnAllow = CreateConVar("sm_tank_spawn_allow", "1", "Allow tank spawn", _, true, 0.0, true, 1.0);
    g_cvWitchSpawnAllow = CreateConVar("sm_witch_spawn_allow", "1", "Allow witch spawn", _, true, 0.0, true, 1.0);

    RegServerCmd("static_tank_map", Cmd_AddStaticTankMap, "static_tank_map <map>");
    RegServerCmd("static_witch_map", Cmd_AddStaticWitchMap, "static_witch_map <map>");
    RegServerCmd("reset_static_maps", Cmd_ResetStaticMaps);
}

public void OnMapStart()
{
    GetCurrentMap(g_szMapName, sizeof(g_szMapName));

    for (int iFlow = MIN_FLOW; iFlow <= MAX_FLOW; iFlow ++)
    {
        SetAvaibleBossFlow(Boss_Tank, iFlow, true);
        SetAvaibleBossFlow(Boss_Witch, iFlow, true);
    }

    char szPathToDir[PLATFORM_MAX_PATH], szPathToFile[PLATFORM_MAX_PATH];
    GetConVarString(g_cvPathToDir, szPathToDir, sizeof(szPathToDir));
    FormatEx(szPathToFile, sizeof(szPathToFile), "%s/%s.cfg", szPathToDir, g_szMapName);

    BanFlowByFile(szPathToFile);

    int iAttemptsFindMaxInterval = GetConVarInt(g_cvAttemptsFindMaxInterval);
    int iTankFlow = GetRandomTankFlow();
    int iWitchFlow = GetRandomWitchFlow();
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

    SetTankFlow(IsMapWithStaticBossSpawn(Boss_Tank, g_szMapName) ? 0 : iTankFlow);
    SetWitchFlow(IsMapWithStaticBossSpawn(Boss_Witch, g_szMapName) ? 0 : iWitchFlow);
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

Action Cmd_AddStaticTankMap(int args)
{
    char szMapName[MAX_MAP_NAME_LENGTH];
    GetCmdArg(1, szMapName, sizeof(szMapName));

    SetTrieValue(g_hStaticTankMaps, szMapName, true);

    return Plugin_Handled;
}

Action Cmd_AddStaticWitchMap(int args)
{
    char szMapName[MAX_MAP_NAME_LENGTH];
    GetCmdArg(1, szMapName, sizeof(szMapName));

    SetTrieValue(g_hStaticWitchMaps, szMapName, true);

    return Plugin_Handled;
}

Action Cmd_ResetStaticMaps(int args)
{
    ClearTrie(g_hStaticWitchMaps);
    ClearTrie(g_hStaticTankMaps);

    return Plugin_Handled;
}

bool IsAvaibleBossFlow(Boss boss, int iFlow) {
    return g_bAvaibleBossFlow[boss][iFlow - 1];
}

void SetAvaibleBossFlow(Boss boss, int iFlow, bool bValue) {
    g_bAvaibleBossFlow[boss][iFlow - 1] = bValue;
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

bool IsMapWithStaticBossSpawn(Boss boss, const char[] szMapName)
{
    bool dummy;

    switch (boss)
    {
        case Boss_Tank: return GetTrieValue(g_hStaticTankMaps, szMapName, dummy);
        case Boss_Witch: return GetTrieValue(g_hStaticWitchMaps, szMapName, dummy);
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

void BanFlowByFile(const char[] szPathToFile)
{
    File hFile = OpenFile(szPathToFile, "rt");

    if (!hFile)
    {
        LogMessage("Could not open file \"%s\"", szPathToFile);
        return;
    }

    char sLine[256];

    while (!hFile.EndOfFile())
    {

        if (!hFile.ReadLine(sLine, sizeof(sLine))) {
            break;
        }

        int iLineLength = strlen(sLine);

        for (int iChar = 0; iChar < iLineLength; iChar++)
        {
            if (sLine[iChar] == '/' && iChar != iLineLength - 1 && sLine[iChar + 1] == '/')
            {
                sLine[iChar] = '\0';
                break;
            }
        }

        TrimString(sLine);

        if ((sLine[0] == '/' && sLine[1] == '/') || (sLine[0] == '\0')) {
            continue;
        }

        ReadLine(sLine);
    }

    hFile.Close();
}

void ReadLine(const char[] sLine)
{
    int iPos = 0;

    char szTarget[16], sValueStart[16], sValueEnd[16];
    iPos += BreakString(sLine[iPos], szTarget, sizeof(szTarget));
    iPos += BreakString(sLine[iPos], sValueStart, sizeof(sValueStart));
    iPos += BreakString(sLine[iPos], sValueEnd, sizeof(sValueEnd));

    int iFlowStart = StringToInt(sValueStart);
    int iFlowEnd = StringToInt(sValueEnd);

    if (!IsValidFlow(iFlowStart) || !IsValidFlow(iFlowEnd)) {
        return;
    }

    Boss boss;

    if (StrEqual(szTarget, "tank", false)) {
        boss = Boss_Tank;
    } else if (StrEqual(szTarget, "witch", false)) {
        boss = Boss_Witch;
    } else {
        return;
    }

    for (int iFlow = iFlowStart; iFlow <= iFlowEnd; iFlow ++)
    {
        SetAvaibleBossFlow(boss, iFlow, false);
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
