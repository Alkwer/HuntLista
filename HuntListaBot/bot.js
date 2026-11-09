/**
 * Hunt Lista Discord Bot
 * 
 * Komendy:
 *   /hunt add <nick> [powód]
 *   /hunt remove <nick>
 *   /hunt list
 *   /hunt info <nick>
 * 
 * Po każdej zmianie bot aktualizuje plik Data.lua na GitHubie.
 */

require('dotenv').config();
const { Client, GatewayIntentBits, REST, Routes, SlashCommandBuilder, EmbedBuilder } = require('discord.js');
const { Octokit } = require('octokit');
const fs = require('fs');
const path = require('path');

// ========== KONFIGURACJA ==========
const DISCORD_TOKEN = process.env.DISCORD_TOKEN;
const CLIENT_ID = process.env.CLIENT_ID;
const GUILD_ID = process.env.GUILD_ID;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_OWNER = process.env.GITHUB_OWNER || 'frethborn';
const GITHUB_REPO = process.env.GITHUB_REPO || 'HuntLista';
const GITHUB_PATH = process.env.GITHUB_PATH || 'HuntLista/Data.lua';

const DATA_FILE = path.join(__dirname, 'local_data.json');

let data = {
    version: '2026-11-09.1',
    lastUpdate: new Date().toISOString().slice(0, 16).replace('T', ' '),
    updatedBy: 'DiscordBot',
    players: {}
};

function loadLocal() {
    if (fs.existsSync(DATA_FILE)) {
        try { data = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8')); } catch (e) { console.error(e.message); }
    }
}

function saveLocal() {
    fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
}

function bumpVersion() {
    const now = new Date();
    const date = now.toISOString().slice(0, 10);
    const old = data.version || '';
    let num = 1;
    if (old.startsWith(date)) {
        const parts = old.split('.');
        num = (parseInt(parts[1]) || 0) + 1;
    }
    data.version = `${date}.${num}`;
    data.lastUpdate = now.toISOString().slice(0, 16).replace('T', ' ');
}

function generateLua() {
    let lua = `-- ============================================================
-- Hunt Lista - Dane (aktualizowane przez bota z Discorda / GitHub)
-- Nie edytuj ręcznie tego pliku jeśli używasz automatycznej aktualizacji.
-- ============================================================

HuntLista_Data = {
    version = "${data.version}",
    lastUpdate = "${data.lastUpdate}",
    updatedBy = "${data.updatedBy}",

    players = {
`;
    const names = Object.keys(data.players).sort((a, b) => a.localeCompare(b));
    for (const name of names) {
        const p = data.players[name];
        lua += `        ["${name}"] = {\n`;
        lua += `            reason = "${(p.reason || '').replace(/"/g, '\\"')}",\n`;
        lua += `            addedBy = "${(p.addedBy || '').replace(/"/g, '\\"')}",\n`;
        lua += `            addedAt = "${p.addedAt || ''}",\n`;
        lua += `            note = "${(p.note || '').replace(/"/g, '\\"')}",\n`;
        lua += `        },\n`;
    }
    lua += `    }
}

HuntLista_Lookup = {}
`;
    return lua;
}

async function pushToGitHub() {
    if (!GITHUB_TOKEN) {
        console.log('Brak GITHUB_TOKEN – pomijam push.');
        return { ok: false, error: 'Brak GITHUB_TOKEN' };
    }
    const octokit = new Octokit({ auth: GITHUB_TOKEN });
    const content = generateLua();
    const contentBase64 = Buffer.from(content).toString('base64');
    try {
        let sha = undefined;
        try {
            const { data: existing } = await octokit.rest.repos.getContent({
                owner: GITHUB_OWNER, repo: GITHUB_REPO, path: GITHUB_PATH,
            });
            sha = existing.sha;
        } catch (e) {}
        await octokit.rest.repos.createOrUpdateFileContents({
            owner: GITHUB_OWNER, repo: GITHUB_REPO, path: GITHUB_PATH,
            message: `Hunt Lista update ${data.version} (${Object.keys(data.players).length} graczy)`,
            content: contentBase64, sha: sha,
        });
        console.log(`✅ Wypchnięto Data.lua na GitHub (${data.version})`);
        return { ok: true };
    } catch (e) {
        console.error('Błąd pusha na GitHub:', e.message);
        return { ok: false, error: e.message };
    }
}

const client = new Client({ intents: [GatewayIntentBits.Guilds] });

const commands = [
    new SlashCommandBuilder()
        .setName('hunt')
        .setDescription('Zarządzanie Hunt Listą')
        .addSubcommand(sub => sub.setName('add').setDescription('Dodaj gracza na listę')
            .addStringOption(o => o.setName('nick').setDescription('Nick gracza').setRequired(true))
            .addStringOption(o => o.setName('powod').setDescription('Powód / notatka').setRequired(false)))
        .addSubcommand(sub => sub.setName('remove').setDescription('Usuń gracza z listy')
            .addStringOption(o => o.setName('nick').setDescription('Nick gracza').setRequired(true)))
        .addSubcommand(sub => sub.setName('list').setDescription('Pokaż całą listę'))
        .addSubcommand(sub => sub.setName('info').setDescription('Szczegóły gracza')
            .addStringOption(o => o.setName('nick').setDescription('Nick gracza').setRequired(true)))
].map(c => c.toJSON());

async function registerCommands() {
    const rest = new REST({ version: '10' }).setToken(DISCORD_TOKEN);
    try {
        if (GUILD_ID) {
            await rest.put(Routes.applicationGuildCommands(CLIENT_ID, GUILD_ID), { body: commands });
            console.log('Komendy zarejestrowane (guild).');
        } else {
            await rest.put(Routes.applicationCommands(CLIENT_ID), { body: commands });
            console.log('Komendy zarejestrowane (global).');
        }
    } catch (e) { console.error('Błąd rejestracji komend:', e); }
}

client.once('ready', () => {
    console.log(`Zalogowano jako ${client.user.tag}`);
    loadLocal();
});

client.on('interactionCreate', async interaction => {
    if (!interaction.isChatInputCommand()) return;
    if (interaction.commandName !== 'hunt') return;

    const sub = interaction.options.getSubcommand();
    const user = interaction.user.username;

    if (sub === 'add') {
        const nick = interaction.options.getString('nick').trim();
        const reason = interaction.options.getString('powod') || '';
        data.players[nick] = { reason, addedBy: user, addedAt: new Date().toISOString().slice(0, 10), note: '' };
        bumpVersion(); saveLocal();
        await interaction.deferReply();
        const result = await pushToGitHub();
        const embed = new EmbedBuilder().setColor(0xff4444).setTitle('Dodano na Hunt Listę')
            .addFields(
                { name: 'Nick', value: nick, inline: true },
                { name: 'Dodał', value: user, inline: true },
                { name: 'Powód', value: reason || '—', inline: false },
                { name: 'Wersja danych', value: data.version, inline: true },
            );
        if (!result.ok) embed.setFooter({ text: `Uwaga: nie udało się wypchnąć na GitHub (${result.error})` });
        else embed.setFooter({ text: 'Wypchnięto na GitHub – zaktualizujcie addon w grze' });
        await interaction.editReply({ embeds: [embed] });
    }
    else if (sub === 'remove') {
        const nick = interaction.options.getString('nick').trim();
        let found = null;
        for (const key of Object.keys(data.players)) {
            if (key.toLowerCase() === nick.toLowerCase()) { found = key; break; }
        }
        if (!found) { await interaction.reply({ content: `Nie ma **${nick}** na liście.`, ephemeral: true }); return; }
        delete data.players[found];
        bumpVersion(); saveLocal();
        await interaction.deferReply();
        const result = await pushToGitHub();
        await interaction.editReply({ content: `Usunięto **${found}** z listy. Wersja: \`${data.version}\`${result.ok ? ' (GitHub OK)' : ' (błąd GitHuba)'}` });
    }
    else if (sub === 'list') {
        const names = Object.keys(data.players).sort((a, b) => a.localeCompare(b));
        if (names.length === 0) { await interaction.reply({ content: 'Lista jest pusta.', ephemeral: true }); return; }
        let text = names.map(n => {
            const p = data.players[n];
            return `• **${n}**${p.reason ? ` — ${p.reason}` : ''} _(dodał: ${p.addedBy})_`;
        }).join('\n');
        if (text.length > 3900) text = text.slice(0, 3900) + '\n…';
        const embed = new EmbedBuilder().setColor(0xff4444).setTitle(`Hunt Lista (${names.length})`)
            .setDescription(text).setFooter({ text: `Wersja: ${data.version} • ${data.lastUpdate}` });
        await interaction.reply({ embeds: [embed] });
    }
    else if (sub === 'info') {
        const nick = interaction.options.getString('nick').trim();
        let found = null;
        for (const key of Object.keys(data.players)) {
            if (key.toLowerCase() === nick.toLowerCase()) { found = key; break; }
        }
        if (!found) { await interaction.reply({ content: `Nie ma **${nick}** na liście.`, ephemeral: true }); return; }
        const p = data.players[found];
        const embed = new EmbedBuilder().setColor(0xff4444).setTitle(found)
            .addFields(
                { name: 'Powód', value: p.reason || '—', inline: false },
                { name: 'Dodał', value: p.addedBy || '—', inline: true },
                { name: 'Data', value: p.addedAt || '—', inline: true },
                { name: 'Notatka', value: p.note || '—', inline: false },
            );
        await interaction.reply({ embeds: [embed] });
    }
});

if (!DISCORD_TOKEN) {
    console.error('Brak DISCORD_TOKEN w .env');
    process.exit(1);
}

registerCommands().then(() => {
    client.login(DISCORD_TOKEN);
});
