# Build and apply the Barrios theme on the KITCHEN site

You already opened the **Branding theme builder** earlier (the screen showing
Primary theme color + Secondary colors, with Add color buttons). This file
walks through finishing that build and getting it applied to the site so the
new pages render with navy / gold / blue chrome.

## Barrios palette to enter

| Role           | Hex       |
| -------------- | --------- |
| Primary        | `#182039` (navy) |
| Secondary 1    | `#E8B86A` (gold) |
| Secondary 2    | `#333333` (charcoal text) |
| Secondary 3    | `#4961A3` (muted blue) |

## Step 1 -- Open the theme builder

The exact path varies by tenant. Try these in order until one works.

**Path A (most common on modern tenants):**

1. Open the site: https://nasa.sharepoint.com/teams/PCTransitionSandbox
2. Click the **gear icon** (top right)
3. Click **Change the look**
4. Click **Theme**
5. At the bottom of the theme list, look for **Manage themes** or **Add a theme**
6. Click that to open the theme builder

**Path B (if your tenant exposes the Brand center directly):**

1. Open https://nasa.sharepoint.com/_layouts/15/sharepoint.aspx (or your tenant's brand center URL)
2. Look for **Themes** or **Branding**
3. Click **Create a theme**

**Path C (if neither works -- the Branding section directly):**

1. Gear -> **Site information**
2. Look for **Site branding** or a **Brand center** link
3. Click into it -> **Themes** -> **Create**

If none of these expose the theme builder, the feature may be admin-restricted
on this tenant -- tell me and we fall back to picking the closest built-in
theme (Dark Blue is the nearest match).

## Step 2 -- Build the theme

Once you are in the builder (the one you saw earlier with Add color buttons):

1. **Primary theme color** -> click into the field -> enter `#182039`
2. Click **Add color** under Secondary colors -> enter `#E8B86A`
3. Click **Add color** again -> enter `#333333`
4. Click **Add color** again -> enter `#4961A3`
5. Watch the right-hand preview update so the navy + gold + charcoal + blue
   color combinations appear (the screenshot you sent earlier showed this
   correctly already)
6. Click **Next** at the bottom

## Step 3 -- Name and save

1. Theme name field: `KITCHEN - Barrios`
2. Description (optional): `Barrios Technology brand palette: navy primary, gold accent, muted blue, charcoal text`
3. Click **Save** (or **Create**)

The theme should now appear in your site's theme picker.

## Step 4 -- Apply the theme to the site

1. Gear -> **Change the look**
2. Click **Theme**
3. Scroll the theme list -- your `KITCHEN - Barrios` theme should appear
   (usually at the top of custom themes, or the bottom of the full list)
4. Click it
5. Click **Save**

The site chrome (suite bar, navigation, default web part accents) shifts to
navy / gold immediately.

## Step 5 -- Verify

Open the site home page. Check:

- Navigation rail across the top tints navy
- Default link colors are blue / navy
- Buttons (e.g., "+ New" in lists) take a navy / blue accent
- Hover / focus states feel coherent

If anything still looks default-Microsoft-blue, hard-refresh (Ctrl+F5) -- the
theme caches per browser session.

## If it does NOT work

Tell me which step failed:

- "The Branding builder is not anywhere I can find" -> tenant likely restricts
  custom themes to admins. We pick the closest built-in (Dark Blue) and live
  with it for now.
- "I can build the theme but it does not appear in Change the look" -> theme
  may be saved at the wrong scope (org vs site). Walk me through what you see.
- "The theme appears but Save fails" -> probably a permission gap. Screenshot
  the error.

## Hub site caveat

If the KITCHEN site is associated to a SharePoint hub, the hub's theme can
override the site theme. To check: Gear -> **Site information**. If you see
"Hub site association: <some hub>", the hub theme wins. Either disassociate
or change the hub theme.
