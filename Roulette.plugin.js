
/**
 * @name DiscordTimestampLogger
 * @author OpenAI
 * @description Enregistre les timestamps des messages envoyés et des réponses des bots Discord.
 * @version 1.1.0
 */

module.exports = class DiscordTimestampLogger {
    constructor() {
        this.pluginName = "DiscordTimestampLogger";
        this.fs = null;
        this.path = null;
        this.outputFile = null;
        this.pendingMessages = new Map();
        this.dispatcher = null;
        this.messageHandler = null;
        this.subscribed = false;
        this.userId = null;
    }

    start() {
        try {
            this.fs = require("fs");
            this.path = require("path");

            this.outputFile = this.path.join(
                BdApi.Plugins.folder,
                "message_timestamps.txt"
            );

            // Utilise le dispatcher que tes diagnostics ont identifié.
            const messageStore =
                BdApi.Webpack.getStore("MessageStore");

            this.dispatcher = messageStore?._dispatcher;

            if (
                !this.dispatcher ||
                typeof this.dispatcher.subscribe !== "function" ||
                typeof this.dispatcher.unsubscribe !== "function"
            ) {
                throw new Error(
                    "Dispatcher de MessageStore introuvable."
                );
            }

            const userStore = BdApi.Webpack.getStore("UserStore");
            const user = userStore?.getCurrentUser?.();

            if (!user?.id) {
                throw new Error(
                    "Impossible de récupérer l'utilisateur courant."
                );
            }

            this.userId = user.id;

            // Crée le fichier s'il n'existe pas, sans écraser son contenu.
            if (!this.fs.existsSync(this.outputFile)) {
                this.fs.writeFileSync(
                    this.outputFile,
                    "=== Journal des timestamps Discord ===\n",
                    "utf8"
                );
            }

            this.pendingMessages.clear();

            this.messageHandler = event => {
                try {
                    this.handleMessage(event);
                } catch (error) {
                    console.error(
                        "[DiscordTimestampLogger] Erreur de traitement :",
                        error
                    );
                }
            };

            this.dispatcher.subscribe(
                "MESSAGE_CREATE",
                this.messageHandler
            );

            this.subscribed = true;

            this.appendLine(
                "=== Session démarrée : " +
                this.formatTimestamp(Date.now()) +
                " ==="
            );

            BdApi.UI.showToast(
                "DiscordTimestampLogger activé",
                { type: "success" }
            );

            console.log(
                "[DiscordTimestampLogger] Actif. Fichier :",
                this.outputFile
            );
        } catch (error) {
            console.error(
                "[DiscordTimestampLogger] Erreur au démarrage :",
                error
            );

            BdApi.UI?.showToast?.(
                "TimestampLogger : " + error.message,
                { type: "error" }
            );

            this.stop();
        }
    }

    stop() {
        if (
            this.subscribed &&
            this.dispatcher &&
            this.messageHandler
        ) {
            try {
                this.dispatcher.unsubscribe(
                    "MESSAGE_CREATE",
                    this.messageHandler
                );
            } catch (error) {
                console.error(
                    "[DiscordTimestampLogger] Désabonnement impossible :",
                    error
                );
            }
        }

        this.subscribed = false;
        this.messageHandler = null;
        this.dispatcher = null;
        this.pendingMessages.clear();

        console.log("[DiscordTimestampLogger] Arrêté.");
    }

    formatTimestamp(milliseconds) {
        return new Date(milliseconds).toISOString();
    }

    getMessageTimestamp(message) {
        const value = message?.timestamp;

        if (
            typeof value === "string" ||
            value instanceof Date
        ) {
            const parsed = value instanceof Date
                ? value.getTime()
                : Date.parse(value);

            if (Number.isFinite(parsed)) {
                return parsed;
            }
        }

        if (typeof value === "number" && Number.isFinite(value)) {
            return value < 100000000000
                ? Math.round(value * 1000)
                : Math.round(value);
        }

        // Repli : heure de réception de l'événement.
        return Date.now();
    }

    appendLine(line) {
        try {
            this.fs.appendFileSync(
                this.outputFile,
                line + "\n",
                "utf8"
            );
        } catch (error) {
            console.error(
                "[DiscordTimestampLogger] Impossible d'écrire le fichier :",
                error
            );
        }
    }

    handleMessage(event) {
        // Selon la version de Discord, le payload peut être
        // directement le message ou un objet contenant "message".
        const message = event?.message || event;

        if (!message?.author) return;

        const channelId =
            message.channel_id ||
            message.channelId ||
            event?.channelId;

        if (!channelId) return;

        const authorId = message.author.id;
        if (!authorId) return;

        const timestamp = this.getMessageTimestamp(message);
        const messageId = message.id || "unknown";

        // Message envoyé par ton propre compte.
        if (authorId === this.userId) {
            if (!this.pendingMessages.has(channelId)) {
                this.pendingMessages.set(channelId, []);
            }

            this.pendingMessages.get(channelId).push({
                messageId,
                sentAt: timestamp,
                channelId
            });

            this.appendLine(
                "[MESSAGE_ENVOYE]" +
                " | timestamp_iso=" + this.formatTimestamp(timestamp) +
                " | unix_ms=" + timestamp +
                " | channel_id=" + channelId +
                " | message_id=" + messageId
            );

            return;
        }

        // Les réponses de bots uniquement.
        if (message.author.bot !== true) return;

        const queue = this.pendingMessages.get(channelId);

        if (!queue || queue.length === 0) return;

        // Si le bot référence un message, on privilégie cette association.
        const referencedId =
            message.message_reference?.message_id ||
            message.messageReference?.message_id;

        let index = 0;

        if (referencedId) {
            const found = queue.findIndex(
                item => item.messageId === referencedId
            );

            if (found !== -1) index = found;
        }

        const pending = queue.splice(index, 1)[0];

        if (queue.length === 0) {
            this.pendingMessages.delete(channelId);
        }

        const delay = timestamp - pending.sentAt;

        this.appendLine(
            "[REPONSE_BOT]" +
            " | timestamp_iso=" + this.formatTimestamp(timestamp) +
            " | unix_ms=" + timestamp +
            " | channel_id=" + channelId +
            " | bot_id=" + authorId +
            " | bot_message_id=" + messageId +
            " | message_envoye_id=" + pending.messageId +
            " | delai_ms=" + delay
        );

        console.log(
            "[DiscordTimestampLogger] Réponse enregistrée :",
            {
                channelId,
                botId: authorId,
                envoi: this.formatTimestamp(pending.sentAt),
                reponse: this.formatTimestamp(timestamp),
                delaiMs: delay
            }
        );
    }
};
