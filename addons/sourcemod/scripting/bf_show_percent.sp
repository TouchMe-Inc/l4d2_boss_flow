#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <boss_flow>
#include <colors>


public Plugin myinfo =
{
	name = "BossFlowShowPercent",
	author = "TouchMe",
	description = "N/a",
	version = "build0000",
	url = "https://github.com/TouchMe-Inc/l4d2_boss_flow"
}


#define TRANSLATIONS            "bf_show_percent.phrases"


ConVar g_cvVsBossBuffer = null;


/**
 * Called before OnPluginStart.
 *
 * @param myself            Handle to the plugin.
 * @param late              Whether or not the plugin was loaded "late" (after map load).
 * @param error             Error message buffer in case load failed.
 * @param err_max           Maximum number of characters for error message buffer.
 * @return                  APLRes_Success | APLRes_SilentFailure.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion engine = GetEngineVersion();

	if (engine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	// Load translations.
	LoadTranslations(TRANSLATIONS);

	g_cvVsBossBuffer = FindConVar("versus_boss_buffer");

	RegConsoleCmd("sm_boss", Cmd_Boss);
	RegConsoleCmd("sm_tank", Cmd_Boss);
	RegConsoleCmd("sm_witch", Cmd_Boss);
	RegConsoleCmd("sm_current", Cmd_Boss);
}

/**
 * When a player wants to find out whos becoming tank,
 * output to them.
 */
Action Cmd_Boss(int iClient, int iArgs)
{
	int iRound = InSecondHalfOfRound() ? 1 : 0;

	float fBossBuffer = GetConVarFloat(g_cvVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();

	char sBracketStart[16]; FormatEx(sBracketStart, sizeof(sBracketStart), "%T", "BRACKET_START", iClient);
	char sBracketMiddle[16]; FormatEx(sBracketMiddle, sizeof(sBracketMiddle), "%T", "BRACKET_MIDDLE", iClient);
	char sBracketEnd[16]; FormatEx(sBracketEnd, sizeof(sBracketEnd), "%T", "BRACKET_END", iClient);

	CPrintToChat(iClient, "%s%T", sBracketStart, "TAG", iClient);

	if (IsTankSpawnAllow())
	{
		char sTankPercent[32], sTankTriggerPercent[32];

		int iTankPercent = RoundToNearest(L4D2Direct_GetVSTankFlowPercent(iRound) * 100.0);
		int iTankTriggerPercent = iTankPercent - RoundToNearest(fBossBuffer * 100.0);

		if (IsStaticTankMap())
		{
			FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "STATIC", iClient);
			FormatEx(sTankTriggerPercent, sizeof(sTankTriggerPercent), "%T", "STATIC", iClient);
		}
		
		else if (iTankPercent == 0)
		{
			FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "DISABLE", iClient);
			FormatEx(sTankTriggerPercent, sizeof(sTankTriggerPercent), "%T", "DISABLE", iClient);
		}
		
		else
		{
			FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "PERCENT", iClient, iTankPercent);
			FormatEx(sTankTriggerPercent, sizeof(sTankTriggerPercent), "%T", "PERCENT", iClient, iTankTriggerPercent);
		}

		CPrintToChat(iClient, "%s%T", sBracketMiddle, "TANK_FLOW", iClient, sTankTriggerPercent, sTankPercent);
	}

	if (IsWitchSpawnAllow())
	{
		char sWitchPercent[32], sWitchTriggerPercent[32];

		int iWitchPercent = RoundToNearest( L4D2Direct_GetVSWitchFlowPercent(iRound) * 100.0);
		int iWitchTriggerPercent = iWitchPercent - RoundToNearest(fBossBuffer * 100.0);

		if (IsStaticWitchMap())
		{
			FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "STATIC", iClient);
			FormatEx(sWitchTriggerPercent, sizeof(sWitchTriggerPercent), "%T", "STATIC", iClient);
		}
		
		else if (iWitchPercent == 0)
		{
			FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "DISABLE", iClient);
			FormatEx(sWitchTriggerPercent, sizeof(sWitchTriggerPercent), "%T", "STATIC", iClient);
		}
		
		else
		{
			FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "PERCENT", iClient, iWitchPercent);
			FormatEx(sWitchTriggerPercent, sizeof(sWitchTriggerPercent), "%T", "PERCENT", iClient, iWitchTriggerPercent);
		}
	
		CPrintToChat(iClient, "%s%T", sBracketMiddle, "WITCH_FLOW", iClient, sWitchTriggerPercent, sWitchPercent);
	}
	
	CPrintToChat(iClient, "%s%T", sBracketEnd, "SURVIVOR_FLOW", iClient, GetFurthestSurvivorFlowPercent());

	return Plugin_Handled;
}

/**
 * Checks if the current round is the second.
 *
 * @return                  Returns true if is second round, otherwise false.
 */
bool InSecondHalfOfRound() {
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

int GetFurthestSurvivorFlowPercent()
{
	int iFlow = RoundToCeil(100.0 * (L4D2_GetFurthestSurvivorFlow()) / L4D2Direct_GetMapMaxFlowDistance());
	return iFlow < 100 ? iFlow : 100;
}
