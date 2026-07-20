---
layout: default
title: Glow
---

<section class="hero" aria-labelledby="hero-title">
  <div class="hero__copy">
    <p class="eyebrow">iPhone + iPad <span aria-hidden="true">·</span> Habits without pressure</p>
    <h1 id="hero-title">Small practices. Clear progress. No guilt.</h1>
    <p class="hero__lede">Glow is a calm habit tracker for building a daily rhythm, celebrating what you completed, and understanding your progress over time.</p>
    <div class="hero__actions">
      <a class="button button--primary" href="{{ site.github_url }}">View on GitHub <span aria-hidden="true">↗</span></a>
      <a class="button button--quiet" href="#daily-loop">See the daily loop</a>
    </div>
    <ul class="signal-list" aria-label="Project foundation">
      <li>SwiftUI</li>
      <li>SwiftData</li>
      <li>CloudKit fallback</li>
      <li>Home widget</li>
    </ul>
  </div>

  <aside class="status-card" aria-labelledby="build-status-title">
    <div class="status-card__topline">
      <span class="status-pill"><span class="status-dot" aria-hidden="true"></span>{{ site.status_label }}</span>
      <span class="status-card__meta">Today</span>
    </div>
    <div class="house-mark" aria-hidden="true">
      <span></span><span></span><span></span><span></span>
    </div>
    <p class="status-card__kicker">Current experience</p>
    <h2 id="build-status-title">Know what is due.<br>Notice what you did.</h2>
    <dl class="status-list">
      <div><dt>Daily check-ins</dt><dd>Ready</dd></div>
      <div><dt>Progress insights</dt><dd>Ready</dd></div>
      <div><dt>Home widget</dt><dd>Included</dd></div>
    </dl>
  </aside>
</section>

<section class="section" aria-labelledby="principles-title">
  <div class="section-heading">
    <p class="eyebrow">A quieter kind of tracker</p>
    <h2 id="principles-title">Progress should feel useful, not demanding.</h2>
    <p>Glow keeps the important loop short: see today clearly, check in quickly, and look back when reflection actually helps.</p>
  </div>

  <div class="principle-grid">
    <article class="principle-card">
      <span class="card-number" aria-hidden="true">01</span>
      <h3>Today stays focused</h3>
      <p>Due, completed, bonus, and upcoming practices are separated into a dashboard that is easy to scan.</p>
    </article>
    <article class="principle-card">
      <span class="card-number" aria-hidden="true">02</span>
      <h3>Check-ins stay light</h3>
      <p>Completion is fast, local, and easy to undo—without turning a small correction into a workflow.</p>
    </article>
    <article class="principle-card">
      <span class="card-number" aria-hidden="true">03</span>
      <h3>Insights stay human</h3>
      <p>Streaks, weekly activity, patterns, milestones, and history reveal momentum without adding judgment.</p>
    </article>
  </div>
</section>

<section class="section section--split" id="daily-loop" aria-labelledby="today-title">
  <article class="resident-card">
    <div class="resident-card__header">
      <div class="resident-icon" aria-hidden="true">
        <span></span><span></span><span></span>
      </div>
      <div>
        <p class="eyebrow">Today</p>
        <h2 id="today-title">One useful daily view</h2>
      </div>
    </div>
    <p class="resident-card__summary">Your schedule, current progress, completed practices, and next steps stay together—so checking in never requires hunting through the app.</p>
    <div class="boundary-note">
      <strong>Built for the everyday loop</strong>
      <span>Today · Insights · Library</span>
    </div>
    <ul class="capability-list">
      <li><span aria-hidden="true">✓</span> Flexible schedules and reminders</li>
      <li><span aria-hidden="true">✓</span> Quick completion with undo</li>
      <li><span aria-hidden="true">✓</span> Streaks, weekly summaries, and history</li>
      <li><span aria-hidden="true">✓</span> Archive without losing past progress</li>
    </ul>
  </article>

  <div class="run-flow" aria-labelledby="flow-title">
    <p class="eyebrow">A sustainable rhythm</p>
    <h2 id="flow-title">Plan less. Practice more.</h2>
    <ol>
      <li><span>01</span><div><strong>Add a practice</strong><p>Name it and choose its schedule.</p></div></li>
      <li><span>02</span><div><strong>Set a reminder</strong><p>Use a gentle cue when it helps.</p></div></li>
      <li><span>03</span><div><strong>Open Today</strong><p>See what fits this day.</p></div></li>
      <li><span>04</span><div><strong>Check in</strong><p>Mark the practice complete in one step.</p></div></li>
      <li><span>05</span><div><strong>Glance back</strong><p>Notice streaks and weekly movement.</p></div></li>
      <li><span>06</span><div><strong>Adjust gently</strong><p>Edit, reschedule, or archive as life changes.</p></div></li>
    </ol>
  </div>
</section>

<section class="section foundation" aria-labelledby="foundation-title">
  <div>
    <p class="eyebrow">Private by design</p>
    <h2 id="foundation-title">Your habits work locally first.</h2>
  </div>
  <p>Glow stores progress with SwiftData and keeps the app usable if CloudKit setup is unavailable. Shared App Group values power the home-screen widget, while reminders and archived habits follow the same schedule rules as the app.</p>
</section>
