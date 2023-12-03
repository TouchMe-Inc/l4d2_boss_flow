#include <sourcemod>
#include <left4dhooks>


public Plugin myinfo =
{
	name = "BossFlow",
	author = "TouchMe",
	description = "Manipulating boss spawns",
	version = "build0000",
	url = "https://github.com/TouchMe-Inc/l4d2_boss_flow"
}


#define MIN_FLOW 1
#define MAX_FLOW 100


char g_sMapName[64];

bool
	g_bValidTankFlow[MAX_FLOW] = {true, ...},
	g_bValidWitchFlow[MAX_FLOW] = {true, ...}
;

Handle
	g_hStaticTankMaps,
	g_hStaticWitchMaps
;

ConVar
	g_cvPathToDir = null,
	g_cvTankSpawnAllow = null,
	g_cvWitchSpawnAllow = null
;

ConVar
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
	EngineVersion engine = GetEngineVersion();

	if (engine != Engine_Left4Dead2)
	{
		strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	CreateNative("IsTankSpawnAllow", Native_IsTankSpawnAllow);
	CreateNative("IsWitchSpawnAllow", Native_IsWitchSpawnAllow);
	CreateNative("IsStaticTankMap", Native_IsStaticTankMap);
	CreateNative("IsStaticWitchMap", Native_IsStaticWitchMap);
	CreateNative("IsValidTankFlowPercent", Native_IsValidTankFlowPercent);
	CreateNative("IsValidWitchFlowPercent", Native_IsValidWitchFlowPercent);
	CreateNative("SetTankFlowPercent", Native_SetTankFlowPercent);
	CreateNative("SetWitchFlowPercent", Native_SetWitchFlowPercent);

	RegPluginLibrary("boss_flow");

	return APLRes_Success;
}

public int Native_IsTankSpawnAllow(Handle plugin, int numParams) {
	return GetConVarBool(g_cvTankSpawnAllow);
}
	
public int Native_IsWitchSpawnAllow(Handle plugin, int numParams) {
	return GetConVarBool(g_cvWitchSpawnAllow);
}

public int Native_IsStaticTankMap(Handle plugin, int numParams) {
	return IsStaticTankMap(g_sMapName);
}

public int Native_IsStaticWitchMap(Handle plugin, int numParams) {
	return IsStaticWitchMap(g_sMapName);
}

public int Native_IsValidTankFlowPercent(Handle plugin, int numParams)
{
	int iFlow = GetNativeCell(1);

	if (!IsValidFlow(iFlow)) {
		ThrowNativeError(SP_ERROR_NATIVE, "The value must be between 1 and 100");
	}

	if (!IsValidConVarFlow(iFlow)) {
		return 0;
	}

	return IsValidTankFlow(iFlow);
}

public int Native_IsValidWitchFlowPercent(Handle plugin, int numParams)
{
	int iFlow = GetNativeCell(1);

	if (!IsValidFlow(iFlow)) {
		ThrowNativeError(SP_ERROR_NATIVE, "The value must be between 1 and 100");
	}

	if (!IsValidConVarFlow(iFlow)) {
		return 0;
	}

	return IsValidWitchFlow(iFlow);
}

public int Native_SetTankFlowPercent(Handle plugin, int numParams)
{
	int iPercent = GetNativeCell(1);

	SetTankFlowPercent(iPercent);

	return 1;
}

public int Native_SetWitchFlowPercent(Handle plugin, int numParams)
{
	int iPercent = GetNativeCell(1);

	SetWitchFlowPercent(iPercent);

	return 1;
}

public void OnMapInit(const char[] sMapName)
{
	strcopy(g_sMapName, sizeof(g_sMapName), sMapName);

	for (int iFlow = MIN_FLOW; iFlow <= MAX_FLOW; iFlow ++)
	{
		SetValidTankFlow(iFlow, true);
		SetValidWitchFlow(iFlow, true);
	}

	char sPathToDir[PLATFORM_MAX_PATH], sPathToFile[PLATFORM_MAX_PATH];
	GetConVarString(g_cvPathToDir, sPathToDir, sizeof(sPathToDir));
	FormatEx(sPathToFile, sizeof(sPathToFile), "%s/%s.cfg", sPathToDir, sMapName);

	InvalidFlowByFile(sPathToFile);
}

public void OnMapStart()
{
	SetTankFlowPercent(IsStaticTankMap(g_sMapName) ? 0 : GetRandomTankFlow());
	SetWitchFlowPercent(IsStaticWitchMap(g_sMapName) ? 0 : GetRandomWitchFlow());
}

public void OnPluginStart()
{
	g_hStaticTankMaps = CreateTrie();
	g_hStaticWitchMaps = CreateTrie();

	g_cvPathToDir = CreateConVar("sm_boss_flow_path_to_dir", "addons/sourcemod/configs/boss_flow");
	g_cvTankSpawnAllow = CreateConVar("sm_tank_spawn_allow", "1", "Allow tank spawn", _, true, 0.0, true, 1.0);
	g_cvWitchSpawnAllow = CreateConVar("sm_witch_spawn_allow", "1", "Allow witch spawn", _, true, 0.0, true, 1.0);

	g_cvVsBossFlowMin = FindConVar("versus_boss_flow_min");
	g_cvVsBossFlowMax = FindConVar("versus_boss_flow_max");

	RegServerCmd("static_tank_map", Cmd_AddStaticTankMap, "static_tank_map <map>");
	RegServerCmd("static_witch_map", Cmd_AddStaticWitchMap, "static_witch_map <map>");
	RegServerCmd("reset_static_maps", Cmd_ResetStaticMaps);
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
	char sMapName[64]; GetCmdArg(1, sMapName, sizeof(sMapName));

	SetTrieValue(g_hStaticTankMaps, sMapName, true);

	return Plugin_Handled;
}

Action Cmd_AddStaticWitchMap(int args)
{
	char sMapName[64]; GetCmdArg(1, sMapName, sizeof(sMapName));

	SetTrieValue(g_hStaticWitchMaps, sMapName, true);

	return Plugin_Handled;
}

Action Cmd_ResetStaticMaps(int args)
{
	ClearTrie(g_hStaticWitchMaps);
	ClearTrie(g_hStaticTankMaps);

	return Plugin_Handled;
}

bool IsValidTankFlow(int iFlow) {
	return g_bValidTankFlow[iFlow - 1];
}

bool IsValidWitchFlow(int iFlow) {
	return g_bValidWitchFlow[iFlow - 1];
}

void SetValidTankFlow(int iFlow, bool bValue) {
	g_bValidTankFlow[iFlow - 1] = bValue;
}

void SetValidWitchFlow(int iFlow, bool bValue) {
	g_bValidWitchFlow[iFlow - 1] = bValue;
}

bool IsValidFlow(int iFlow) {
	return (iFlow > 0 && iFlow <= MAX_FLOW);
}

bool IsValidConVarFlow(int iFlow)
{
	int iMinFlow = RoundToCeil(GetConVarFloat(g_cvVsBossFlowMin) * 100.0);
	int iMaxFlow = RoundToFloor(GetConVarFloat(g_cvVsBossFlowMax) * 100.0);

	return (iFlow >= iMinFlow && iFlow <= iMaxFlow);
}

int GetRandomTankFlow()
{
	int iTankFlow = 0;

	Handle hValidTankFlow = CreateArray();

	int iMinFlow = RoundToCeil(GetConVarFloat(g_cvVsBossFlowMin) * 100.0);
	int iMaxFlow = RoundToFloor(GetConVarFloat(g_cvVsBossFlowMax) * 100.0);

	for (int iFlow = iMinFlow + 1; iFlow <= iMaxFlow - 1; iFlow ++)
	{
		if (!IsValidTankFlow(iFlow)) {
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

	int iMinFlow = RoundToCeil(GetConVarFloat(g_cvVsBossFlowMin) * 100.0);
	int iMaxFlow = RoundToFloor(GetConVarFloat(g_cvVsBossFlowMax) * 100.0);

	for (int iFlow = iMinFlow; iFlow < iMaxFlow; iFlow ++)
	{
		if (!IsValidWitchFlow(iFlow)) {
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

bool IsStaticTankMap(const char[] sMapName)
{
	bool dummy;
	return GetTrieValue(g_hStaticTankMaps, sMapName, dummy);
}

bool IsStaticWitchMap(const char[] sMapName)
{
	bool dummy;
	return GetTrieValue(g_hStaticWitchMaps, sMapName, dummy);
}

void SetTankFlowPercent(int iFlow)
{
	float fPersent = (float(iFlow) / 100.0);

	L4D2Direct_SetVSTankFlowPercent(0, fPersent);
	L4D2Direct_SetVSTankFlowPercent(1, fPersent);

	bool bCanSpawn = view_as<bool>(iFlow);

	L4D2Direct_SetVSTankToSpawnThisRound(0, bCanSpawn);
	L4D2Direct_SetVSTankToSpawnThisRound(1, bCanSpawn);
}

void SetWitchFlowPercent(int iFlow)
{
	float fPersent = (float(iFlow) / 100.0);

	L4D2Direct_SetVSWitchFlowPercent(0, fPersent);
	L4D2Direct_SetVSWitchFlowPercent(1, fPersent);

	bool bCanSpawn = view_as<bool>(iFlow);

	L4D2Direct_SetVSWitchToSpawnThisRound(0, bCanSpawn);
	L4D2Direct_SetVSWitchToSpawnThisRound(1, bCanSpawn);
}

void InvalidFlowByFile(const char[] sFileName)
{
	File hFile = OpenFile(sFileName, "rt");

	if (!hFile)
	{
		LogMessage("Could not open file \"%s\"", sFileName);
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
			if (sLine[iChar] == '/' && iChar != iLineLength - 1 && sLine[iChar+1] == '/')
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

	char sTarget[16];
	iPos += BreakString(sLine[iPos], sTarget, sizeof(sTarget));

	char sType[16];
	iPos += BreakString(sLine[iPos], sType, sizeof(sType));

	if (StrEqual(sType, "element"))
	{
		char sValue[16];
		iPos += BreakString(sLine[iPos], sValue, sizeof(sValue));

		int iFlow = StringToInt(sValue);

		if (!IsValidFlow(iFlow)) {
			return;
		}

		if (StrEqual(sTarget, "tank")) {
			SetValidTankFlow(iFlow, false);
		}

		else if (StrEqual(sTarget, "witch")) {
			SetValidWitchFlow(iFlow, false);
		}
	}

	else if (StrEqual(sType, "interval"))
	{
		char sValueStart[16], sValueEnd[16];
		iPos += BreakString(sLine[iPos], sValueStart, sizeof(sValueStart));
		iPos += BreakString(sLine[iPos], sValueEnd, sizeof(sValueEnd));

		int iFlowStart = StringToInt(sValueStart);
		int iFlowEnd = StringToInt(sValueEnd);

		if (!IsValidFlow(iFlowStart) || !IsValidFlow(iFlowEnd)) {
			return;
		}

		if (StrEqual(sTarget, "tank"))
		{
			for (int iFlow = iFlowStart; iFlow <= iFlowEnd; iFlow ++)
			{
				SetValidTankFlow(iFlow, false);
			}
		}

		else if (StrEqual(sTarget, "witch"))
		{
			for (int iFlow = iFlowStart; iFlow <= iFlowEnd; iFlow ++)
			{
				SetValidWitchFlow(iFlow, false);
			}
		}
	}
}
