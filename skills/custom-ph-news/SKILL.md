---
name: ph-news
description: Fetch, organize, or summarize Philippine news. Use when the user asks for PH news, Philippine headlines, local news RSS feeds, or news updates from the Philippines.
---

# Philippine News & RSS Feed Skill

When the user asks for Philippine news, headlines, or RSS sources, use this structured reference to guide your response or fetch live data if web tools are available.

## Primary News Outlets & RSS Directory

### 1. National & General News
- **GMA News Online**
  - Direct XML Feed: `https://data.gmanews.tv/gno/rss/news/feed.xml`
  - Full Directory: `https://www.gmanetwork.com/news/rss/`
- **Inquirer.net**
  - Main Feed: `https://www.inquirer.net/feed`
  - Headlines Feed: `https://newsinfo.inquirer.net/feed`
- **Philstar.com**
  - Headlines Feed: `https://www.philstar.com/rss/headlines`
  - Nation Feed: `https://www.philstar.com/rss/nation`
  - Full Directory: `https://www.philstar.com/rss`

### 2. Business & Regional News
- **BusinessWorld**: `https://www.bworldonline.com/feed/`
- **SunStar Philippines**: `https://www.sunstar.com.ph/feed`

---

## Agent Guidelines & Output Rules

1. **If the user asks for RSS Feed links/directories:**
   - Group outlets logically (General/National vs. Business/Regional).
   - Provide direct XML URLs and mention the WordPress wildcard rule (`/feed` or `/rss` appended to category paths).

2. **If live web search or RSS fetching is available:**
   - Fetch headlines from the top national feeds (`Inquirer`, `Philstar`, `GMA News`).
   - Summarize key developments in 3–5 bullet points under broad categories: **Nation**, **Business**, **Technology/Lifestyle**.

3. **Tone & Constraints:**
   - Maintain objective, neutral journalistic language.
   - Always attribute news items clearly to the reporting source.