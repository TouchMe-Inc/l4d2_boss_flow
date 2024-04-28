#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <left4dhooks>
#include <boss_flow>
#include <colors>


public Plugin myinfo = {
	name = "BossFlowShowPercent",
	author = "TouchMe",
	description = "Plugin displays boss locations",
	version = "build0003",
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
	if (GetEngineVersion() != Engine_Left4Dead2)
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

Action Cmd_Boss(int iClient, int iArgs)
{
	float fBossBuffer = GetConVarFloat(g_cvVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();

	CPrintToChat(iClient, "%T%T", "BRACKET_START", iClient, "TAG", iClient);

	if (IsTankSpawnAllow())
	{
		int iTankPercent = GetTankFlowPercent();

		if (IsStaticTankMap()) {
			CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "TANK_STATIC", iClient);
		}

		else if (iTankPercent == 0) {
			CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "TANK_DISABLED", iClient);
		}

		else
		{
			int iTankTriggerPercent = iTankPercent - RoundToNearest(fBossBuffer * 100.0);

			if (iTankTriggerPercent < 0) {
				iTankTriggerPercent = 1;
			}

			CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "TANK_FLOW", iClient, iTankTriggerPercent, iTankPercent);
		}
	}

	if (IsWitchSpawnAllow())
	{
		int iWitchPercent = GetWitchFlowPercent();

		if (IsStaticWitchMap()) {
			CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "WITCH_STATIC", iClient);
		}

		else if (iWitchPercent == 0) {
			CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "WITCH_DISABLED", iClient);
		}

		else
		{
			int iWitchTriggerPercent = iWitchPercent - RoundToNearest(fBossBuffer * 100.0);

			if (iWitchTriggerPercent < 0) {
				iWitchTriggerPercent = 1;
			}

			CPrintToChat(iClient, "%T%T", "BRACKET_MIDDLE", iClient, "WITCH_FLOW", iClient, iWitchTriggerPercent, iWitchPercent);
		}
	}

	CPrintToChat(iClient, "%T%T", "BRACKET_END", iClient, "SURVIVOR_FLOW", iClient, GetFurthestSurvivorFlowPercent());

	return Plugin_Handled;
}

int GetFurthestSurvivorFlowPercent()
{
	int iFlow = RoundToCeil(100.0 * (L4D2_GetFurthestSurvivorFlow()) / L4D2Direct_GetMapMaxFlowDistance());
	return iFlow < 100 ? iFlow : 100;
}
