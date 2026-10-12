
let active = false;

const rows: {
    channelId: string;
    messageId: string;
    replyMessageId: string;
    botId: string;
    sentISO: string;
    replyISO: string;
    delayMs: number;
}[] = [];

function onLoad() {
    active = true;
    console.log("[DiscordTimestampLogger] Plugin chargé.");
    console.log(
        "[DiscordTimestampLogger] L'écouteur de messages doit être raccordé à l'API de la version de Kettu utilisée."
    );
}

function onUnload() {
    active = false;
    console.log("[DiscordTimestampLogger] Plugin arrêté.");
}

function exportTXT(): string {
    const header = [
        "channel_id",
        "message_id",
        "reply_message_id",
        "bot_id",
        "envoi_iso",
        "reponse_iso",
        "delai_ms"
    ].join("\t");

    return [
        header,
        ...rows.map(row => [
            row.channelId,
            row.messageId,
            row.replyMessageId,
            row.botId,
            row.sentISO,
            row.replyISO,
            row.delayMs
        ].join("\t"))
    ].join("\n");
}

export default {
    onLoad,
    onUnload
};
