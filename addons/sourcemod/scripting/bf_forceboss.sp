#pragma semicolon               1
#pragma newdecls                required

#include <colors>
#include <sdktools>
#include <boss_flow>
#include <colors>


public Plugin myinfo =
{
	name = "BossFlowForceBoss",
	author = "TouchMe",
	description = "N/A",
	version = "build0000",
	url = "https://github.com/TouchMe-Inc/l4d2_boss_flow"
}


#define TRANSLATIONS            "bf_forceboss.phrases"

#define MIN_FLOW 1
#define MAX_FLOW 100


bool g_bRoundIsLive = false;


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

	// Event hooks.
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", Event_LeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	// Player Commands.
	RegAdminCmd("sm_forceboss", Cmd_ForceBoss, ADMFLAG_BAN,  "Gives the tank to a selected player");
}

/**
 * Round start event.
 */
void Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast) {
	g_bRoundIsLive = false;
}

/**
 * Round start event.
 */
void Event_LeftStartArea(Event event, const char[] sName, bool bDontBroadcast) {
	g_bRoundIsLive = true;
}

/**
 * Round end event.
 */
void Event_RoundEnd(Event event, const char[] sName, bool bDontBroadcast) {
	g_bRoundIsLive = false;
}

/**
 * Give the tank to a specific player.
 */
Action Cmd_ForceBoss(int iClient, int iArgs)
{
	if (iArgs != 2)
	{
		CPrintToChat(iClient, "%T%T", "TAG", iClient, "INVALID_ARGS", iClient);
		return Plugin_Handled;
	}

	if (InSecondHalfOfRound())
	{
		CPrintToChat(iClient, "%T%T", "TAG", iClient, "INVALID_ROUND", iClient);
		return Plugin_Handled;
	}

	if (IsRoundStarted())
	{
		CPrintToChat(iClient, "%T%T", "TAG", iClient, "ROUND_STARTED", iClient);
		return Plugin_Handled;
	}

	char sTankPercentParam[4]; GetCmdArg(1, sTankPercentParam, sizeof(sTankPercentParam));
	char sWitchPercentParam[4]; GetCmdArg(2, sWitchPercentParam, sizeof(sWitchPercentParam));

	int iTankPercent = (sTankPercentParam[0] == '-' || !IsTankSpawnAllow()) ? -1 : 0;
	int iWitchPercent = (sWitchPercentParam[0] == '-' || !IsWitchSpawnAllow()) ? -1 : 0;

	char sErrorMessage[192];
	bool bIsStaticTankMap = IsStaticTankMap();
	bool bIsStaticWitchMap = IsStaticWitchMap();

	Handle hErrorMessages = CreateArray(ByteCountToCells(sizeof(sErrorMessage)));

	if (iTankPercent != -1 && !bIsStaticTankMap)
	{
		iTankPercent = StringToInt(sTankPercentParam);

		if (iTankPercent)
		{
			if (!IsValidPercent(iTankPercent))
			{
				FormatEx(sErrorMessage, sizeof(sErrorMessage), "%T", "INVALID_TANK_PERCENT", iClient);
				PushArrayString(hErrorMessages, sErrorMessage);
			}

			else if (!IsValidTankFlowPercent(iTankPercent))
			{
				FormatEx(sErrorMessage, sizeof(sErrorMessage), "%T", "INVALID_TANK_FLOW", iClient, iTankPercent);
				PushArrayString(hErrorMessages, sErrorMessage);
			}
		}
	}

	if (iWitchPercent != -1 && !bIsStaticWitchMap)
	{
		iWitchPercent = StringToInt(sWitchPercentParam);

		if (iWitchPercent)
		{
			if (!IsValidPercent(iWitchPercent))
			{
				FormatEx(sErrorMessage, sizeof(sErrorMessage), "%T", "INVALID_WITCH_PERCENT", iClient);
				PushArrayString(hErrorMessages, sErrorMessage);
			}

			else if (!IsValidWitchFlowPercent(iWitchPercent))
			{
				FormatEx(sErrorMessage, sizeof(sErrorMessage), "%T", "INVALID_WITCH_FLOW", iClient, iWitchPercent);
				PushArrayString(hErrorMessages, sErrorMessage);
			}
		}
	}

	if (iTankPercent == iWitchPercent && iTankPercent > 0 && iWitchPercent > 0)
	{
		FormatEx(sErrorMessage, sizeof(sErrorMessage), "%T", "INVALID_BOSS_POINT", iClient);
		PushArrayString(hErrorMessages, sErrorMessage);
	}

	int iArraySize = GetArraySize(hErrorMessages);

	if (iArraySize)
	{
		char sBracketStart[16]; FormatEx(sBracketStart, sizeof(sBracketStart), "%T", "BRACKET_START", iClient);
		char sBracketMiddle[16]; FormatEx(sBracketMiddle, sizeof(sBracketMiddle), "%T", "BRACKET_MIDDLE", iClient);
		char sBracketEnd[16]; FormatEx(sBracketEnd, sizeof(sBracketEnd), "%T", "BRACKET_END", iClient);

		CPrintToChat(iClient, "%s%T", sBracketStart, "TAG", iClient);

		for (int iIndex = 0; iIndex < iArraySize; iIndex ++)
		{
			GetArrayString(hErrorMessages, iIndex, sErrorMessage, sizeof(sErrorMessage));
			CPrintToChat(iClient, "%s%s", (iIndex + 1) == iArraySize ? sBracketEnd : sBracketMiddle, sErrorMessage);
		}

		CloseHandle(hErrorMessages);
		return Plugin_Handled;
	}

	CloseHandle(hErrorMessages);

	if (iTankPercent != -1 && !bIsStaticTankMap) {
		SetTankFlowPercent(iTankPercent);
	}

	if (iWitchPercent != -1 && !bIsStaticWitchMap) {
		SetWitchFlowPercent(iWitchPercent);
	}

	char sTankPercent[32], sWitchPercent[32];

	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
	{
		if (!IsClientInGame(iPlayer) || !IsFakeClient(iPlayer)) {
			continue;
		}

		if (iTankPercent == -1) {
			FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "IGNORED", iPlayer);
		} else if (bIsStaticTankMap) {
			FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "STATIC", iPlayer);
		} else if (iTankPercent == 0) {
			FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "DISABLE", iPlayer);
		} else {
			FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "PERCENT", iPlayer, iTankPercent);
		}

		if (iWitchPercent == -1) {
			FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "IGNORED", iPlayer);
		} else if (bIsStaticTankMap) {
			FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "STATIC", iPlayer);
		} else if (iWitchPercent == 0) {
			FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "DISABLE", iPlayer);
		} else {
			FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "PERCENT", iPlayer, iWitchPercent);
		}

		CPrintToChat(iPlayer, "%T%T", "TAG", iPlayer, "ADMIN_FLOW_UPDATE", iPlayer, iClient, sTankPercent, sWitchPercent);
	}

	return Plugin_Handled;
}

/**
 *
 */
bool IsRoundStarted() {
	return g_bRoundIsLive;
}

/**
 *
 */
bool IsValidPercent(int iPercent) {
	return iPercent >= MIN_FLOW && iPercent <= MAX_FLOW;
}

/**
 * Checks if the current round is the second.
 *
 * @return                  Returns true if is second round, otherwise false.
 */
bool InSecondHalfOfRound() {
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}
