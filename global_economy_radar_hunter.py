#!/usr/bin/env python3
"""
Global Macro Economy Radar Hunter Engine
========================================
Compiles cross-border macroeconomic indicators, superpower telemetry
(US, China, Europe, Japan, India & EM Asia), global stress barometers,
and the US vs China Macro Clash Matrix.

Outputs:
 - assets/data/global_economy_radar.json (App bundled baseline)
 - global_economy_radar.json (CDN live endpoint)
"""

import os
import json
from datetime import datetime, timezone

OUTPUT_ASSET_FILE = "assets/data/global_economy_radar.json"
OUTPUT_ROOT_FILE = "global_economy_radar.json"

GLOBAL_RADAR_PAYLOAD = {
    "metadata": {
        "title": "Global Macro Economy Pressure & Expansion Radar",
        "generated_timestamp": datetime.now(timezone.utc).isoformat(),
        "last_updated": "November 2024 / Q4 Macro Baseline",
        "global_regime": "BIFURCATED_LIQUIDITY_CYCLE",
        "regime_headline": "US AI Capex & Tariff 2.0 vs China Debt Deflation & Factory Overcapacity",
        "global_conclusion": (
            "The world economy is split between US technological capex resilience and Chinese industrial overcapacity dumping. "
            "While US 10Y yields (~4.42%) and King Dollar (DXY >106) create emerging market liquidity friction, "
            "China's domestic deflation and cheap commodity supply chains provide major input-cost tailwinds to India."
        )
    },
    "executive_hud": {
        "global_health_score": 54.2,
        "global_health_label": "MODERATE FRAGMENTED EXPANSION",
        "health_verdict": "Resilient US Tech & Asian China+1 offsetting European de-industrialization and Chinese property debt deflation.",
        "regions_expansion_count": 3,
        "regions_pressure_count": 2,
        "core_pillars": [
            {
                "region_id": "us",
                "region": "UNITED STATES",
                "flag": "🇺🇸",
                "gdp_trillion_usd": 28.7,
                "growth_pmi": 54.9,
                "growth_pmi_label": "Services PMI",
                "status": "EXPANSION",
                "status_type": "EXPANSION",
                "flow_color": "cyan",
                "net_momentum_pct": 2.8,
                "key_driver": "$250B+ AI Data Center Capex & Fed Easing Cycle"
            },
            {
                "region_id": "china",
                "region": "CHINA",
                "flag": "🇨🇳",
                "gdp_trillion_usd": 18.5,
                "growth_pmi": 50.3,
                "growth_pmi_label": "Caixin Composite",
                "status": "DEFLATIONARY PRESSURE",
                "status_type": "PRESSURE",
                "flow_color": "red",
                "net_momentum_pct": 4.8,
                "key_driver": "Real Estate Deflation (-10.3%) vs ¥10T Debt Swap Stimulus"
            },
            {
                "region_id": "europe",
                "region": "EUROZONE / UK",
                "flag": "🇪🇺",
                "gdp_trillion_usd": 19.4,
                "growth_pmi": 46.0,
                "growth_pmi_label": "Mfg PMI",
                "status": "DEEP CONTRACTION",
                "status_type": "PRESSURE",
                "flow_color": "red",
                "net_momentum_pct": 0.7,
                "key_driver": "German Auto Slump, Energy Shocks & French Fiscal Deficits"
            },
            {
                "region_id": "japan",
                "region": "JAPAN",
                "flag": "🇯🇵",
                "gdp_trillion_usd": 4.2,
                "growth_pmi": 51.2,
                "growth_pmi_label": "Composite PMI",
                "status": "MODEST REBOUND",
                "status_type": "EXPANSION",
                "flow_color": "cyan",
                "net_momentum_pct": 1.2,
                "key_driver": "30-Year High Wage Hikes (+5.2%) & Semicon Onshoring"
            },
            {
                "region_id": "em_india",
                "region": "INDIA & EM ASIA",
                "flag": "🇮🇳",
                "gdp_trillion_usd": 7.6,
                "growth_pmi": 58.6,
                "growth_pmi_label": "Composite PMI",
                "status": "RAPID EXPANSION",
                "status_type": "EXPANSION",
                "flow_color": "green",
                "net_momentum_pct": 7.2,
                "key_driver": "China+1 Supply Chain Shift & Domestic Capex Execution"
            }
        ]
    },
    "global_superpowers": [
        {
            "id": "us",
            "name": "United States of America",
            "flag": "🇺🇸",
            "economic_status": "MODERATE_EXPANSION",
            "status_label": "TECH & FISCAL RESILIENCE",
            "central_bank_rate": "4.50% - 4.75% (Fed Cutting Cycle)",
            "inflation_rate": "3.3% Core CPI (Sticky Shelter & Insurance)",
            "pmi_summary": "Services 54.9 (Booming) • Mfg 48.5 (Soft)",
            "vital_stats": {
                "debt_to_gdp": "124% ($35.8 Trillion)",
                "annual_interest_cost": "$1.12 Trillion (> Defense Budget)",
                "us_10y_yield": "4.42% (Bond Vigilante Risk)",
                "mortgage_30y": "6.85% (Housing Freeze)",
                "ai_hyperscaler_capex": "$250 Billion+ (Generational Ramp)",
                "oil_gas_output": "13.5M bpd (Global Record)"
            },
            "pressure_points": [
                {
                    "title": "Universal Tariffs 2.0 & Global Trade War Threat",
                    "description": "Proposed universal 10-20% baseline tariffs and 60% duties on China threaten to reignite import inflation, strengthen DXY, and disrupt global multi-national corporate supply chains.",
                    "severity": "CRITICAL"
                },
                {
                    "title": "$35.8T Sovereign Debt & $1.12T Annual Interest Burden",
                    "description": "Annual federal interest servicing cost has surpassed the entire US Defense budget ($850B), forcing massive Treasury bond issuance waves and steepening the yield curve.",
                    "severity": "HIGH"
                },
                {
                    "title": "US 10-Year Yield Spike (~4.42%) & Equity PE Gravity",
                    "description": "Persistent long-term Treasury yields above 4.4% raise corporate discount rates, exerting continuous multiple compression on global high-valuation equities.",
                    "severity": "HIGH"
                },
                {
                    "title": "Commercial Real Estate (CRE) & Regional Banking Risk",
                    "description": "Over $2.2 Trillion in CRE debt matures through 2026 amid remote-work urban vacancies, keeping regional lenders under credit surveillance.",
                    "severity": "MODERATE"
                },
                {
                    "title": "K-Shaped Consumer Bifurcation & Debt Delinquencies",
                    "description": "Top 20% thrive on stock market and real estate wealth, while lower-income consumer credit card and auto loan 90+ day delinquencies have hit 12-year highs.",
                    "severity": "MODERATE"
                },
                {
                    "title": "Power Grid Bottlenecks for AI Data Centers",
                    "description": "Massive hyperscaler compute clusters are straining legacy electric utilities, leading to power shortages and delays in data center energization.",
                    "severity": "MODERATE"
                }
            ],
            "expansion_engines": [
                {
                    "title": "$250B+ Generative AI Compute Supercycle",
                    "description": "Hyperscalers (Microsoft, Meta, Google, Amazon, Oracle) driving unprecedented capex in GPU clusters, optical transceivers, and liquid cooling systems.",
                    "impact": "TECH REVOLUTION"
                },
                {
                    "title": "Nuclear Power Revival for Big Tech (SMRs & PPA Deals)",
                    "description": "Big tech contracting directly with nuclear operators (Three Mile Island revival, Talen Energy, SMR startups) to secure 24/7 carbon-free base-load power.",
                    "impact": "ENERGY SUPERCYCLE"
                },
                {
                    "title": "Federal Reserve Interest Rate Easing Cycle",
                    "description": "Fed trimming policy rates provides liquidity relief, lowers commercial paper refinancing frictions, and supports corporate debt rollover.",
                    "impact": "LIQUIDITY INJECTION"
                },
                {
                    "title": "Domestic Energy Dominance (13.5M bpd Crude Oil)",
                    "description": "US record hydrocarbon production and massive LNG export terminals ensure industrial energy independence and insulate US factories from foreign price shocks.",
                    "impact": "ENERGY SECURITY"
                },
                {
                    "title": "CHIPS Act & IRA Domestic Re-Shoring Wave",
                    "description": "Over $400B in announced semiconductor fabs (TSMC Phoenix, Intel Ohio, Samsung Texas) and clean energy battery plants actively under construction.",
                    "impact": "INDUSTRIAL RESHORING"
                },
                {
                    "title": "Positive Real Wage Growth & Services Dominance",
                    "description": "With gasoline and goods inflation abating, median wage growth exceeds inflation, anchoring retail consumption and domestic services spending.",
                    "impact": "CONSUMER RESILIENCE"
                }
            ]
        },
        {
            "id": "china",
            "name": "China (People's Republic of China)",
            "flag": "🇨🇳",
            "economic_status": "DEFLATIONARY_PRESSURE",
            "status_label": "STIMULUS BAZOOKA DEFENSE",
            "central_bank_rate": "3.10% (PBOC Easing Cycle)",
            "inflation_rate": "0.3% CPI • -2.9% PPI (25-Month Deflation)",
            "pmi_summary": "Caixin Mfg 50.3 (Borderline) • Services 52.0",
            "vital_stats": {
                "real_estate_investment": "-10.3% YoY (Property Slump)",
                "hidden_lgfv_debt": "¥60 Trillion ($8.3T Municipal Debt)",
                "stimulus_swap_package": "¥10 Trillion Local Debt Relief",
                "producer_deflation": "-2.9% PPI (25 Straight Months)",
                "youth_unemployment": "17.1% (Ages 16-24 Urban)",
                "clean_tech_dominance": ">80% Global Solar & LFP Batteries"
            },
            "pressure_points": [
                {
                    "title": "Real Estate Collapse & Balance Sheet Recession",
                    "description": "70% of urban wealth was concentrated in property; ongoing developer insolvencies and 30%+ price drops have triggered a severe Japanese-style consumer balance sheet recession.",
                    "severity": "CRITICAL"
                },
                {
                    "title": "Persistent Factory-Gate Deflation (-2.9% PPI)",
                    "description": "Industrial overcapacity has caused 25 straight months of negative producer prices, eviscerating corporate profit margins and driving predatory price wars.",
                    "severity": "CRITICAL"
                },
                {
                    "title": "¥60 Trillion Local Government (LGFV) Hidden Debt",
                    "description": "With land sales crashing, municipal authorities face massive revenue shortfalls, delaying payments to contractors, healthcare providers, and local workers.",
                    "severity": "HIGH"
                },
                {
                    "title": "Western Tariff Walls & 'China Shock 2.0' Pushback",
                    "description": "US (up to 100% on EVs) and EU (up to 45.3%) imposing heavy anti-subsidy duties to prevent Chinese state-backed industrial dumping from wiping out domestic industries.",
                    "severity": "HIGH"
                },
                {
                    "title": "Foreign Direct Investment (FDI) Contraction",
                    "description": "Supply chain relocation and geopolitical friction have caused net inward foreign investment to turn negative, restricting technology transfer.",
                    "severity": "HIGH"
                },
                {
                    "title": "Demographic Cliff & 17.1% Youth Unemployment",
                    "description": "Rapidly aging population alongside high youth joblessness is depressing long-term domestic consumption, forcing consumers toward discount platforms.",
                    "severity": "MODERATE"
                }
            ],
            "expansion_engines": [
                {
                    "title": "¥10 Trillion Local Government Debt Swap Bazooka",
                    "description": "National People's Congress approved a ¥10T ($1.4T) debt-swap quota over 3-5 years to replace toxic high-interest off-balance-sheet debt with low-cost sovereign bonds.",
                    "impact": "MUNICIPAL LIQUIDITY FLOOR"
                },
                {
                    "title": "Absolute Global Monopoly on Clean-Tech Infrastructure",
                    "description": "Controlling >80% of global solar polysilicon, wafers, lithium refining, and LFP EV batteries (CATL & BYD), dominating exports to emerging economies.",
                    "impact": "GLOBAL INDUSTRIAL MONOPOLY"
                },
                {
                    "title": "National Big Fund III Semiconductor Sovereignty (¥344B)",
                    "description": "State-funded $47.5B semiconductor war chest accelerating domestic lithography, SMIC trailing-edge 28nm dominance, and Huawei Ascend AI chip deployment.",
                    "impact": "TECH INDEPENDENCE"
                },
                {
                    "title": "Strategic Rare Earth & Critical Mineral Weaponization",
                    "description": "Controlling 70% of rare earth mining and 90% of processing; restricting Gallium, Germanium, and Antimony exports as leverage against Western sanctions.",
                    "impact": "GEOPOLITICAL LEVERAGE"
                },
                {
                    "title": "Aggressive Monetary Easing & PBOC Liquidity Injections",
                    "description": "Multiple RRR cuts, Loan Prime Rate reductions, and special central bank lending facilities designed to bolster state-owned enterprise balance sheets.",
                    "impact": "CREDIT LIQUIDITY"
                },
                {
                    "title": "Global South & Belt and Road Trade Expansion",
                    "description": "Diversifying exports away from the US towards ASEAN, Middle East, Africa, and Latin America, bypassing traditional Western trade restrictions.",
                    "impact": "MARKET DIVERSIFICATION"
                }
            ]
        },
        {
            "id": "europe",
            "name": "Eurozone & United Kingdom",
            "flag": "🇪🇺",
            "economic_status": "SEVERE_CONTRACTION",
            "status_label": "DE-INDUSTRIALIZATION SHOCK",
            "central_bank_rate": "3.25% (ECB Aggressive Cuts)",
            "inflation_rate": "2.0% HICP (Target Reached)",
            "pmi_summary": "Manufacturing 46.0 (Deep Slump) • Services 51.6",
            "vital_stats": {
                "mfg_pmi": "46.0 (Deep Contraction)",
                "german_industrial_output": "-4.5% YoY",
                "ecb_deposit_rate": "3.25% (Fast Track Cuts)",
                "defense_capex_target": "2.0%+ of GDP across NATO",
                "energy_cost_gap": "3x higher industrial power vs US"
            },
            "pressure_points": [
                {
                    "title": "German Industrial De-Industrialization",
                    "description": "Volkswagen planning unprecedented domestic factory closures, and BASF downsizing chemical manufacturing due to uncompetitive energy costs compared to US and China.",
                    "severity": "CRITICAL"
                },
                {
                    "title": "French & British Fiscal Austerity & Tax Hikes",
                    "description": "Excessive sovereign deficits forcing tax hikes and spending cutbacks, putting further strain on European consumer discretionary demand.",
                    "severity": "HIGH"
                },
                {
                    "title": "Crushing Energy Transition Cost Disadvantage",
                    "description": "High electricity tariffs and strict carbon regulations make European heavy industry non-viable against US shale-backed and Chinese subsidized competitors.",
                    "severity": "HIGH"
                }
            ],
            "expansion_engines": [
                {
                    "title": "Aggressive ECB Interest Rate Cuts",
                    "description": "ECB cutting borrowing rates in 25bps increments to rescue credit markets and lower corporate borrowing burdens.",
                    "impact": "MONETARY EASING"
                },
                {
                    "title": "Historic European Defense Spending Supercycle",
                    "description": "European defense spending exceeding €350B as NATO members rapidly re-arm stockpiles and artillery systems.",
                    "impact": "DEFENSE PROCUREMENT"
                }
            ]
        },
        {
            "id": "japan",
            "name": "Japan",
            "flag": "🇯🇵",
            "economic_status": "MODEST_EXPANSION",
            "status_label": "EXITING 30-YR DEFLATION",
            "central_bank_rate": "0.25% (Bank of Japan Hiking Cycle)",
            "inflation_rate": "2.5% Core CPI (Sustained Above Target)",
            "pmi_summary": "Composite 51.2 (Expansion) • Mfg 49.2",
            "vital_stats": {
                "shunto_wage_growth": "+5.2% (30-Year Record High)",
                "boj_rate": "0.25% (Normalize from Zero)",
                "usd_jpy": "154.5 (Yen Volatility Zone)",
                "semicon_investment": "¥4 Trillion (Rapidus & TSMC Kumamoto)"
            },
            "pressure_points": [
                {
                    "title": "Yen Carry Trade Unwinding Fragility",
                    "description": "Sudden spikes in Japanese bond yields or rapid Yen appreciation trigger multi-billion dollar carry trade liquidations across global equity markets.",
                    "severity": "HIGH"
                },
                {
                    "title": "Imported Inflation Squeezing Household Real Spending",
                    "description": "Weak Yen has driven food and energy import costs up, weighing on middle-class consumer purchasing power.",
                    "severity": "MODERATE"
                }
            ],
            "expansion_engines": [
                {
                    "title": "Shunto Spring Wage Surge (+5.2%)",
                    "description": "Japanese corporations enacted the largest wage hikes in three decades, creating a virtuous wage-price domestic consumption spiral.",
                    "impact": "CONSUMER REFLATION"
                },
                {
                    "title": "Global Semiconductor Fab Buildout (TSMC Kumamoto & Rapidus)",
                    "description": "Japan is reclaiming advanced chipmaking with government subsidies drawing global foundries and equipment giants.",
                    "impact": "HIGH-TECH INDUSTRIAL REBIRTH"
                }
            ]
        },
        {
            "id": "em_india",
            "name": "India & Emerging Asia",
            "flag": "🇮🇳",
            "economic_status": "HIGH_GROWTH_LEADER",
            "status_label": "GLOBAL GROWTH ENGINE",
            "central_bank_rate": "6.50% (RBI Neutral Stance)",
            "inflation_rate": "6.2% Headline (Food Spike) • Core 3.5%",
            "pmi_summary": "Manufacturing 57.5 • Services 59.2 (Composite 58.6)",
            "vital_stats": {
                "composite_pmi": "58.6 (Global Outperformer)",
                "gdp_growth": "7.0% - 7.2% Expected FY25",
                "fastag_toll_runrate": "₹192 Cr / Day (+11.8% YoY)",
                "forex_reserves": "$675 Billion (Strong Warchest)",
                "electronics_exports": "+23.4% YoY (Apple/EMS Surge)"
            },
            "pressure_points": [
                {
                    "title": "Strong US Dollar (DXY >106) & FII Outflows",
                    "description": "Elevated US bond yields and dollar strength triggered tactical foreign portfolio rebalancing out of emerging markets into US assets.",
                    "severity": "HIGH"
                },
                {
                    "title": "Chinese Cheap Industrial Dumping (Steel & Chemicals)",
                    "description": "Subsidized Chinese steel coils, basic chemicals, and solar cells entering India at predatory prices, prompting domestic anti-dumping investigations.",
                    "severity": "HIGH"
                }
            ],
            "expansion_engines": [
                {
                    "title": "China+1 High-Tech Manufacturing Relocation",
                    "description": "Global giants (Apple, HP, Dell, Foxconn) investing billions to scale domestic assembly, pushing electronics exports to record highs.",
                    "impact": "STRUCTURAL CAPEX"
                },
                {
                    "title": "Physical Infrastructure Supercycle",
                    "description": "Government capital expenditure across dedicated freight corridors, highways, ports, and power transmission driving domestic capital goods orders.",
                    "impact": "DOMESTIC DEMAND MULTIPLIER"
                }
            ]
        }
    ],
    "usa_china_macro_clash": {
        "headline": "USA vs CHINA: THE TIT-FOR-TAT GEOPOLITICAL & MACRO CLASH",
        "overview": (
            "The clash between the world's two largest superpowers is reshaping global trade, technology, and capital flows. "
            "Understanding this friction explains where economic pain is concentrated and where emerging markets like India gain structural leverage."
        ),
        "battlefields": [
            {
                "id": "trade_tariffs",
                "title": "1. Trade War 2.0 & Tariff Escalation",
                "icon": "⚔️",
                "us_offensive": "Universal 10-20% baseline tariffs on all global imports, escalating to 60%+ on all Chinese manufacturing, revoking China's PNTR status.",
                "china_retaliation": "Weaponizing export licenses for critical minerals (Gallium, Germanium, Antimony), targeting US agricultural imports (soybeans/pork), and devaluing RMB to 7.30+ to offset tariff penalties.",
                "macro_impact": "Squeezes global trade volumes, re-accelerates US imported inflation, and accelerates supply chain flight out of mainland China into ASEAN and India.",
                "impact_on_india": "POSITIVE (NET BENEFICIARY)",
                "india_takeaway": "Multinationals are compelled to set up secondary manufacturing hubs in India to bypass punitive US tariffs on Chinese origins."
            },
            {
                "id": "tech_chips",
                "title": "2. Semiconductor Blockade & AI Cold War",
                "icon": "💻",
                "us_offensive": "Strict export controls on advanced AI chips (Nvidia H100/H200/Blackwell), ASML extreme UV lithography embargoes, and scrutiny of EDA chip design software.",
                "china_retaliation": "State-funded ¥344B National Big Fund III, mass-producing legacy 28nm silicon to flood global automotive markets, and developing domestic Huawei Ascend AI accelerators.",
                "macro_impact": "Bifurcated global tech standards, accelerated duplicate fab investments ($500B+ globally), and soaring GPU compute costs for Western enterprises.",
                "impact_on_india": "POSITIVE FOR INDIA EMS & DESIGN",
                "india_takeaway": "India semiconductor mission (Tata-PSMC Dholera fab, Micron OSAT, Kaynes EMS) gains strategic Western technology transfer backing."
            },
            {
                "id": "currency_debt",
                "title": "3. King Dollar Dominance vs Sovereign Gold Accumulation",
                "icon": "💵",
                "us_offensive": "King Dollar (DXY >106) powered by high US yields (~4.42%) drains global liquidity and asserts US Treasury sanctions enforcement.",
                "china_retaliation": "PBOC continuous gold reserve accumulation (18-month buying streak), reducing US Treasury holdings below $750B, and expanding CIPS / local currency bilateral settlements.",
                "macro_impact": "Gold hits all-time records ($2,650+/oz), emerging market central banks diversify reserve currencies, and cross-border payment systems fragment.",
                "impact_on_india": "NEUTRAL TO POSITIVE",
                "india_takeaway": "RBI expands gold reserves to record 854+ metric tonnes while settling bilateral trade in Rupee-Dirham with Middle East and Asian partners."
            },
            {
                "id": "industrial_dumping",
                "title": "4. Industrial Overcapacity vs Western Reshoring (China Shock 2.0)",
                "icon": "🏭",
                "us_offensive": "Subsidizing domestic clean tech via the Inflation Reduction Act (IRA) and CHIPS Act, placing 100% tariffs on Chinese EVs.",
                "china_retaliation": "Directing state-bank capital into factories to produce 2-3x domestic consumption in solar, batteries, and steel, dumping inventory overseas at below-cash-cost.",
                "macro_impact": "Severe margin depression for international chemical and steel manufacturers; consumer disinflation in emerging markets purchasing cheap green hardware.",
                "impact_on_india": "MIXED (HEADWIND FOR COMMODITIES, TAILWIND FOR USERS)",
                "india_takeaway": "Hurt: Tata Steel, JSW Steel, UPL (margin squeeze from cheap dumping). Benefit: Solar EPC contractors, real estate developers, and consumer electronics assemblers."
            },
            {
                "id": "energy_monopoly",
                "title": "5. Energy Sovereignty: US Shale vs Chinese Clean-Tech Monopoly",
                "icon": "⚡",
                "us_offensive": "US producing world-record 13.5M bpd crude oil and dominating transatlantic LNG exports, shielding US factories from energy shocks.",
                "china_retaliation": "Controlling 85%+ of global solar wafers, polysilicon refining, and EV battery cell manufacturing, turning green transition into a Chinese hardware monopoly.",
                "macro_impact": "Traditional hydrocarbon energy security centers in the Americas, while renewable hardware relies entirely on Chinese supply chains.",
                "impact_on_india": "POSITIVE ARBITRAGE",
                "india_takeaway": "India benefits from discounted Russian/Middle East crude oil (~$72/bbl) while deploying cheap imported solar cells to accelerate renewable capacity."
            }
        ]
    },
    "global_stress_gauges": [
        {
            "id": "dxy",
            "name": "US Dollar Index (DXY)",
            "current_value": 106.25,
            "unit": "points",
            "stress_level": "ELEVATED PRESSURE",
            "status_label": "STRONG DOLLAR SQUEEZE",
            "bar_ratio": 0.72,
            "flow_direction": "PRESSURE",
            "historical_range": "100.5 - 107.0",
            "market_impact": (
                "A strong DXY above 106 drains emerging market liquidity, pressures the Indian Rupee toward 84.40+, "
                "and triggers foreign institutional investor (FII) reallocations back toward US money markets."
            )
        },
        {
            "id": "us10y",
            "name": "US 10-Year Treasury Yield",
            "current_value": 4.42,
            "unit": "%",
            "stress_level": "HIGH RISK GRAVITY",
            "status_label": "YIELD GRAVITY DABAO",
            "bar_ratio": 0.76,
            "flow_direction": "PRESSURE",
            "historical_range": "3.60% - 5.00%",
            "market_impact": (
                "High US long-term risk-free rates compress global equity price-to-earnings (PE) multiples and raise "
                "refinancing borrowing hurdles for dollar-denominated emerging market corporate debt."
            )
        },
        {
            "id": "brent_crude",
            "name": "Brent Crude Oil",
            "current_value": 73.40,
            "unit": "USD/bbl",
            "stress_level": "MODERATE RELIEF",
            "status_label": "MACRO SWEET SPOT",
            "bar_ratio": 0.45,
            "flow_direction": "EXPANSION",
            "historical_range": "$68 - $92",
            "market_impact": (
                "Oil trading near $70-$75 is a massive economic stabilizer for India, keeping the Current Account Deficit (CAD) "
                "manageable and protecting operating margins for paints, specialty chemicals, and transport sectors."
            )
        },
        {
            "id": "gold_spot",
            "name": "Sovereign Gold (XAU/USD)",
            "current_value": 2655.0,
            "unit": "USD/oz",
            "stress_level": "SAFE HAVEN DEMAND",
            "status_label": "DE-DOLLARIZATION HEDGE",
            "bar_ratio": 0.88,
            "flow_direction": "EXPANSION",
            "historical_range": "$1,980 - $2,790",
            "market_impact": (
                "Gold trading near historic highs confirms aggressive reserve diversification by global central banks (PBOC, RBI, Middle East) "
                "seeking neutral reserves immune to US dollar sanctions."
            )
        },
        {
            "id": "semicon_utilization",
            "name": "Global Semiconductor Fab Utilization",
            "current_value": 94.5,
            "unit": "%",
            "stress_level": "PEAK EXPANSION",
            "status_label": "AI HARDWARE SUPERCYCLE",
            "bar_ratio": 0.94,
            "flow_direction": "EXPANSION",
            "historical_range": "72% - 96%",
            "market_impact": (
                "Near-capacity utilization at leading-edge foundries (TSMC 3nm/5nm) verifies the massive structural demand for AI accelerators, "
                "spilling over into domestic Indian electronic manufacturing (EMS) and packaging orders."
            )
        },
        {
            "id": "baltic_dry",
            "name": "Baltic Dry Shipping Index",
            "current_value": 1680.0,
            "unit": "points",
            "stress_level": "HEALTHY STEADY FLOW",
            "status_label": "BALANCED BULK EXIM",
            "bar_ratio": 0.58,
            "flow_direction": "EXPANSION",
            "historical_range": "1,100 - 2,250",
            "market_impact": (
                "Measures ocean transport rates for iron ore, coal, and grains. Current levels confirm stable "
                "raw material movements without the shipping cost spikes seen during pandemic bottlenecks."
            )
        }
    ],
    "global_headwinds_and_tailwinds": {
        "pressure_headwinds": [
            {
                "title": "US Corporate IT Discretionary Budget Freezes",
                "impact_level": "SEVERE DABAO",
                "affected_sectors": ["Indian IT Services", "US SaaS Software", "Tech Consulting"],
                "reason": "US BFSI and retail executives are reprioritizing discretionary software budgets strictly towards generative AI proof-of-concepts, delaying large multi-year digital transformation deals."
            },
            {
                "title": "Universal US Import Tariff Threat (10% - 60%)",
                "impact_level": "MACRO RISK",
                "affected_sectors": ["Chinese Exporters", "Global Autos", "Steel & Aluminium"],
                "reason": "Proposed tariff escalations threaten to disrupt integrated global supply chains, strengthen the dollar, and reignite US imported consumer inflation."
            },
            {
                "title": "Chinese Industrial Dumping Across Emerging Markets",
                "impact_level": "PRICE DABAO",
                "affected_sectors": ["Primary Steel", "Basic Chemicals", "Agrochemicals"],
                "reason": "With Chinese property demand stagnant, Chinese factories dump excess steel coils and synthetic chemicals into Asian markets at distressed prices, depressing domestic realisations."
            },
            {
                "title": "European Industrial Demand Stagnation",
                "impact_level": "EXPORT DABAO",
                "affected_sectors": ["Specialty Chemicals", "Auto Components", "Textiles"],
                "reason": "With German factory orders and automotive dispatches declining, Indian and Asian exporters of intermediates face delayed purchase orders."
            }
        ],
        "expansion_tailwinds": [
            {
                "title": "China+1 Manufacturing Relocation to India & ASEAN",
                "impact_level": "MASSIVE TAILWIND",
                "affected_sectors": ["Electronics (EMS)", "Solar Modules", "Precision Engineering"],
                "reason": "Global multinational brands are mandating that at least 25-30% of their global component sourcing originate outside mainland China."
            },
            {
                "title": "Muted Crude Oil & Commodity Softness",
                "impact_level": "PROFIT EXPANSION",
                "affected_sectors": ["Paints", "Airlines", "FMCG Packaging", "Tyres"],
                "reason": "Crude oil remaining rangebound ($70-$75) prevents gross margin contraction and keeps national current account deficits in comfortable zones."
            },
            {
                "title": "Global Central Bank Rate-Easing Liquidity Wave",
                "impact_level": "LIQUIDITY EXPANSION",
                "affected_sectors": ["Private Banking", "Real Estate", "Renewable Energy"],
                "reason": "Synchronized rate cuts from the ECB, Bank of England, and US Fed lower global borrowing spreads and reduce corporate interest burdens."
            },
            {
                "title": "AI Infrastructure & Power Equipment Supercycle",
                "impact_level": "GLOBAL DEMAND",
                "affected_sectors": ["Power Transmission", "Transformers", "Data Center EPC"],
                "reason": "Unprecedented energy consumption from AI compute clusters creates global shortage of transformers and high-voltage electrical equipment."
            }
        ]
    },
    "equity_impact_matrix": [
        {
            "theme": "China+1 Global Supply Relocation",
            "impact_direction": "BENEFICIARY",
            "status": "EXPANDING",
            "stocks": [
                {"symbol": "KAYNES", "name": "Kaynes Technology", "catalyst": "Aerospace & defense EMS assembly orders & OSAT packaging"},
                {"symbol": "DIXON", "name": "Dixon Technologies", "catalyst": "Mobile phone & laptop domestic manufacturing expansion"},
                {"symbol": "PGEL", "name": "PG Electroplast", "catalyst": "Consumer electronics ODM contract manufacturing"}
            ]
        },
        {
            "theme": "Global AI Infrastructure & Electrical Power Equipment",
            "impact_direction": "BENEFICIARY",
            "status": "EXPANDING",
            "stocks": [
                {"symbol": "ABB", "name": "ABB India", "catalyst": "Global data center electrification & switchgear exports"},
                {"symbol": "SIEMENS", "name": "Siemens India", "catalyst": "High-voltage grid transmission equipment demand"},
                {"symbol": "VOLTAMP", "name": "Voltamp Transformers", "catalyst": "Multi-year domestic & industrial transformer order backlog"}
            ]
        },
        {
            "theme": "Western Discretionary Tech Freeze",
            "impact_direction": "PRESSURE_FACING",
            "status": "HEADWIND",
            "stocks": [
                {"symbol": "TCS", "name": "Tata Consultancy Services", "catalyst": "US BFSI discretionary deal closure sluggishness"},
                {"symbol": "WIPRO", "name": "Wipro Ltd", "catalyst": "Prolonged consulting restructuring and muted revenue guidance"}
            ]
        },
        {
            "theme": "Chinese Industrial Overcapacity & Steel Dumping",
            "impact_direction": "PRESSURE_FACING",
            "status": "HEADWIND",
            "stocks": [
                {"symbol": "TATASTEEL", "name": "Tata Steel Ltd", "catalyst": "Cheap Chinese hot-rolled coil imports compressing domestic steel spreads"},
                {"symbol": "UPL", "name": "UPL Limited", "catalyst": "Chinese generic agrochemical active ingredients price war"}
            ]
        }
    ]
}

def generate_global_radar():
    print("🌐 Generating Global Macro Economy Pressure & Expansion Radar...")
    for file_path in [OUTPUT_ASSET_FILE, OUTPUT_ROOT_FILE]:
        os.makedirs(os.path.dirname(file_path) or ".", exist_ok=True)
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(GLOBAL_RADAR_PAYLOAD, f, indent=2)
    print(f"✅ Created {OUTPUT_ASSET_FILE} and {OUTPUT_ROOT_FILE}")
    print(f"📊 Superpowers: {len(GLOBAL_RADAR_PAYLOAD['global_superpowers'])} | US vs China Battlefields: {len(GLOBAL_RADAR_PAYLOAD['usa_china_macro_clash']['battlefields'])}")

if __name__ == "__main__":
    generate_global_radar()
