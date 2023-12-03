#pragma semicolon               1
#pragma newdecls                required

#include <colors>
#include <sdktools>
#include <boss_flow>
#include <colors>


public Plugin myinfo =
{
    name        = "BossFlowForceBoss",
    author      = "TouchMe",
    description = "N/A",
    version     = "build_0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_boss_flow"
}


#define TRANSLATIONS            "bf_forceboss.phrases"

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

    // Player Commands.
    RegAdminCmd("sm_forceboss", Cmd_ForceBoss, ADMFLAG_BAN, "Gives the tank to a selected player");
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

    char szTankFlow[4]; GetCmdArg(1, szTankFlow, sizeof(szTankFlow));
    char szWitchFlow[4]; GetCmdArg(2, szWitchFlow, sizeof(szWitchFlow));

    int iTankFlow = (szTankFlow[0] == '-' || !IsBossSpawnAllowed(Boss_Tank)) ? -1 : 0;
    int iWitchFlow = (szWitchFlow[0] == '-' || !IsBossSpawnAllowed(Boss_Witch)) ? -1 : 0;

    bool bIsStaticTankMap = IsMapWithStaticBossSpawn(Boss_Tank);
    bool bIsStaticWitchMap = IsMapWithStaticBossSpawn(Boss_Witch);

    char szErrorMessage[192];
    Handle hErrorMessages = CreateArray(ByteCountToCells(sizeof(szErrorMessage)));

    if (iTankFlow != -1 && !bIsStaticTankMap)
    {
        iTankFlow = StringToInt(szTankFlow);

        int iIsAvaibleTankFlow = IsAvaibleBossFlow(Boss_Tank, iTankFlow);

        if (iIsAvaibleTankFlow == -2)
        {
            FormatEx(szErrorMessage, sizeof(szErrorMessage), "%T", "INVALID_TANK_PERCENT", iClient);
            PushArrayString(hErrorMessages, szErrorMessage);
        }

        else if (iIsAvaibleTankFlow != 1)
        {
            FormatEx(szErrorMessage, sizeof(szErrorMessage), "%T", "INVALID_TANK_FLOW", iClient, iTankFlow);
            PushArrayString(hErrorMessages, szErrorMessage);
        }
    }

    if (iWitchFlow != -1 && !bIsStaticWitchMap)
    {
        iWitchFlow = StringToInt(szWitchFlow);

        if (iWitchFlow)
        {
            int iIsAvaibleWitchFlow = IsAvaibleBossFlow(Boss_Witch, iWitchFlow);

            if (iIsAvaibleWitchFlow == -2)
            {
                FormatEx(szErrorMessage, sizeof(szErrorMessage), "%T", "INVALID_WITCH_PERCENT", iClient);
                PushArrayString(hErrorMessages, szErrorMessage);
            }

            else if (iIsAvaibleWitchFlow != 1)
            {
                FormatEx(szErrorMessage, sizeof(szErrorMessage), "%T", "INVALID_WITCH_FLOW", iClient, iWitchFlow);
                PushArrayString(hErrorMessages, szErrorMessage);
            }
        }
    }

    if (iTankFlow == iWitchFlow && iTankFlow > 0 && iWitchFlow > 0)
    {
        FormatEx(szErrorMessage, sizeof(szErrorMessage), "%T", "INVALID_BOSS_POINT", iClient);
        PushArrayString(hErrorMessages, szErrorMessage);
    }

    int iArraySize = GetArraySize(hErrorMessages);

    if (iArraySize)
    {
        CPrintToChat(iClient, "%T%T", "BRACKET_START", iClient, "TAG", iClient);

        for (int iIndex = 0; iIndex < iArraySize; iIndex ++)
        {
            GetArrayString(hErrorMessages, iIndex, szErrorMessage, sizeof(szErrorMessage));
            CPrintToChat(iClient, "%T%s", (iIndex + 1) == iArraySize ? "BRACKET_END" : "BRACKET_MIDDLE", iClient, szErrorMessage);
        }

        CloseHandle(hErrorMessages);
        return Plugin_Handled;
    }

    CloseHandle(hErrorMessages);

    if (iTankFlow != -1 && !bIsStaticTankMap) {
        SetBossFlow(Boss_Tank, iTankFlow);
    }

    if (iWitchFlow != -1 && !bIsStaticWitchMap) {
        SetBossFlow(Boss_Witch, iWitchFlow);
    }

    char sTankPercent[32], sWitchPercent[32];

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer)) {
            continue;
        }

        if (iTankFlow == -1) {
            FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "IGNORED", iPlayer);
        } else if (bIsStaticTankMap) {
            FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "STATIC", iPlayer);
        } else if (iTankFlow == 0) {
            FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "DISABLE", iPlayer);
        } else {
            FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "PERCENT", iPlayer, iTankFlow);
        }

        if (iWitchFlow == -1) {
            FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "IGNORED", iPlayer);
        } else if (bIsStaticTankMap) {
            FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "STATIC", iPlayer);
        } else if (iWitchFlow == 0) {
            FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "DISABLE", iPlayer);
        } else {
            FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "PERCENT", iPlayer, iWitchFlow);
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
 * Checks if the current round is the second.
 *
 * @return                  Returns true if is second round, otherwise false.
 */
bool InSecondHalfOfRound() {
    return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}
