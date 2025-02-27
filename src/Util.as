// c 2024-01-02
// m 2024-11-25

bool         cancel = false;
const string pbFile = IO::FromStorageFolder("pbs.json").Replace("\\", "/");
Json::Value@ pbs    = Json::Object();

void GetAllPBsAsyncCached() {
    GetAllPBsAsync(true);
}

void GetAllPBsAsyncForceRefresh() {
    GetAllPBsAsync(false);
}

void GetAllPBsAsync(bool useCache) {
    const uint64 start = Time::Now;
    trace("getting all PBs");

    trace("getting PBs for campaign maps (" + mapsCampaign.Length + ")");
    GetAllPBsForMapSet(@mapsCampaign, useCache);

    if (cancel) {
        warn("GetAllPBsAsync(" + useCache + ") cancelled");
        cancel = false;
        gettingNow = false;
        SetNextMapAsync();
        return;
    }

    trace("getting PBs for TOTD maps (" + mapsTotd.Length + ")");
    GetAllPBsForMapSet(@mapsTotd, useCache);

    if (cancel) {
        warn("GetAllPBsAsync(" + useCache + ") cancelled");
        cancel = false;
        gettingNow = false;
        SetNextMapAsync();
        return;
    }

    trace("getting all PBs done after " + (Time::Now - start) + "ms");

    gettingNow = false;
    SetNextMapAsync();
}

void GetAllPBsForMapSet(Map@[]@ maps, bool useCache) {
    uint64 lastYield = Time::Now;
    const uint64 maxFrameTime = 50;

    for (uint i = 0; i < maps.Length; i++) {
        if (cancel) {
            warn("GetAllPBsForMapSet(" + (maps is mapsCampaign ? "mapsCampaign" : "mapsTotd") + ", " + useCache + ") cancelled");
            return;
        }

        Map@ map = maps[i];

        if (map is null)
            continue;

        print("\\$444" + i + " / " + maps.Length);

        map.GetPB(useCache);

        const uint64 now = Time::Now;
        if (now - lastYield > maxFrameTime) {
            lastYield = now;
            yield();
        }
    }
}

void HoverTooltip(const string &in msg) {
    if (!UI::IsItemHovered())
        return;

    UI::BeginTooltip();
    UI::Text(msg);
    UI::EndTooltip();
}

void LoadPBs() {
    if (!IO::FileExists(pbFile)) {
        warn("not found: " + pbFile);
        return;
    }

    trace("loading " + pbFile);

    try {
        @pbs = Json::FromFile(pbFile);
    } catch {
        warn("failed loading PBs: " + getExceptionInfo());
        @pbs = Json::Object();
    }
}

void Notify() {
    switch (S_Target) {
        case TargetMedal::Author: NotifyAuthor(); break;
        case TargetMedal::Gold:   NotifyGold();   break;
        case TargetMedal::Silver: NotifySilver(); break;
        case TargetMedal::Bronze: NotifyBronze(); break;
        default:                  NotifyNone();
    }
}

void NotifyAuthor() {
    UI::ShowNotification(title, "Author achieved!" + (S_AutoSwitch ? " Switching map..." : ""), vec4(S_ColorMedalAuthor.x, S_ColorMedalAuthor.y, S_ColorMedalAuthor.z, 0.8f));
}

void NotifyGold() {
    UI::ShowNotification(title, "Gold achieved!" + (S_AutoSwitch ? " Switching map..." : ""), vec4(S_ColorMedalGold.x, S_ColorMedalGold.y, S_ColorMedalGold.z, 0.8f));
}

void NotifySilver() {
    UI::ShowNotification(title, "Silver achieved!" + (S_AutoSwitch ? " Switching map..." : ""), vec4(S_ColorMedalSilver.x, S_ColorMedalSilver.y, S_ColorMedalSilver.z, 0.8f));
}

void NotifyBronze() {
    UI::ShowNotification(title, "Bronze achieved!" + (S_AutoSwitch ? " Switching map..." : ""), vec4(S_ColorMedalBronze.x, S_ColorMedalBronze.y, S_ColorMedalBronze.z, 0.8f));
}

void NotifyNone() {
    UI::ShowNotification(title, "Map finished!" + (S_AutoSwitch ? " Switching map..." : ""), vec4(S_ColorMedalNone.x, S_ColorMedalNone.y, S_ColorMedalNone.z, 0.8f));
}

void NotifyTimeNeeded(bool pb) {
    if (
        S_NotifyAfterRun == NotifyAfterRun::Never ||
        (S_NotifyAfterRun == NotifyAfterRun::OnlyAfterPB && !pb)
    )
        return;

    int target = 0;

    switch (S_Target) {
        case TargetMedal::Author: target = nextMap.authorTime; break;
        case TargetMedal::Gold:   target = nextMap.goldTime;   break;
        case TargetMedal::Silver: target = nextMap.silverTime; break;
        case TargetMedal::Bronze: target = nextMap.bronzeTime; break;
        default:;
    }

    const string text = (pb ? "Better, but y" : "Not fast enough! Y") + "ou still need " + Time::Format(int(nextMap.myTime) - target) + " for " + tostring(S_Target);
    trace(text);
    UI::ShowNotification(title, text, vec4(S_ColorTimeNeeded.x, S_ColorTimeNeeded.y, S_ColorTimeNeeded.z, 0.8f));
}

// courtesy of "BetterTOTD" plugin - https://github.com/XertroV/tm-better-totd
void ReturnToMenu() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    if (App.Network.PlaygroundClientScriptAPI.IsInGameMenuDisplayed)
        App.Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit);

    App.BackToMainMenu();

    while (!App.ManiaTitleControlScriptAPI.IsReady)
        yield();
}

void SavePBs(bool log = true) {
    if (log)
        trace("saving " + pbFile);

    try {
        Json::ToFile(pbFile, pbs);
    } catch {
        warn("error saving PBs: " + getExceptionInfo());
    }
}

string TimeFormatColored(uint u, bool format = true) {
    if (u > 0)
        return "\\$0F0" + (format ? Time::Format(u) : tostring(u));

    return "\\$G0" + (format ? ":00.000" : "");
}

string ZPad2(int num) {
    return (num < 10 ? "0" : "") + num;
}

string ZPad4(int num) {
    return (num < 10 ? "000" : num < 100 ? "00" : num < 1000 ? "0" : "") + num;
}
