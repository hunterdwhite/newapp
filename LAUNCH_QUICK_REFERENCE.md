# 🚀 Production Launch - Quick Reference Card

**Print this or keep it open during launch preparation**

---

## ⚡ Critical Path (Do These First)

```
┌─────────────────────────────────────────────────────┐
│ 1. Deploy Firestore Indexes          │ 30 min  ⚠️ │
│    firebase deploy --only firestore:indexes        │
├─────────────────────────────────────────────────────┤
│ 2. Fix Security Rule (line 54)       │ 15 min  🔐 │
│    firestore.rules - prevent credit manipulation   │
├─────────────────────────────────────────────────────┤
│ 3. Enable Backups                    │ 60 min  💾 │
│    gcloud scheduler - daily exports               │
├─────────────────────────────────────────────────────┤
│ 4. Add Critical Tests                │ 4-6 hrs 🧪 │
│    test/critical_flows_test.dart                  │
├─────────────────────────────────────────────────────┤
│ 5. Update README                     │ 30 min  📚 │
│    Setup instructions for new devs                │
└─────────────────────────────────────────────────────┘

TOTAL TIME: 3-5 DAYS
```

---

## 🔴 BLOCKER CHECKLIST

Before you can launch, verify:

- [ ] **Firestore indexes deployed** - Check Firebase Console → Firestore → Indexes
- [ ] **Security rule fixed** - No unrestricted user updates
- [ ] **Backups running** - Cloud Scheduler job active
- [ ] **Critical tests passing** - `flutter test` shows green
- [ ] **README updated** - Team can set up from scratch
- [ ] **Backup procedures documented** - Team knows how to recover
- [ ] **Crashlytics alerting on** - Email/Slack alerts working
- [ ] **Payment tested end-to-end** - Real $1 charge + refund
- [ ] **Deployment checklist created** - No steps forgotten

**All 9 items must be checked before launch ✓**

---

## 📊 Quick Status Check

```bash
# Check if indexes are deployed
firebase firestore:indexes list

# Run tests
flutter test

# Check for linter errors
flutter analyze

# Verify backups
gsutil ls gs://your-project-firestore-backups/

# Check Crashlytics
# → Go to Firebase Console → Crashlytics
```

---

## 🚨 Emergency Commands

**Rollback deployment:**
```bash
firebase rollback
```

**Force stop all Cloud Functions:**
```bash
firebase functions:delete --force
```

**Emergency backup NOW:**
```bash
gcloud firestore export gs://your-project-firestore-backups/emergency-$(date +%Y%m%d-%H%M%S)
```

**Check recent errors:**
```bash
gcloud logging read "severity>=ERROR" --limit 50 --project=your-project-id
```

---

## 📞 Launch Day Checklist

**Morning of Launch:**
- [ ] All team members available
- [ ] Rollback plan reviewed
- [ ] Monitoring dashboards open
- [ ] Support email/slack monitored

**During Launch:**
- [ ] Deploy backend first
- [ ] Wait 10 minutes, check health
- [ ] Deploy Firebase functions
- [ ] Wait 10 minutes, check health  
- [ ] Release app to stores (staged rollout)
- [ ] Monitor for 1 hour continuously

**Post-Launch (First Hour):**
- [ ] Place test order
- [ ] Check Crashlytics (no new errors)
- [ ] Check Firebase costs (normal)
- [ ] Monitor user feedback
- [ ] Respond to any issues immediately

**Post-Launch (First Day):**
- [ ] Check Crashlytics every 2 hours
- [ ] Monitor payment success rate
- [ ] Review user feedback
- [ ] Document any issues
- [ ] Update team on status

---

## 🎯 Success Metrics

After 24 hours, you should see:

| Metric | Target | Check |
|--------|--------|-------|
| Crash-free users | > 99% | Firebase Console |
| Payment success rate | > 98% | Stripe Dashboard |
| API response time (p95) | < 500ms | Performance Monitoring |
| User signups | Tracking | Firebase Analytics |

---

## ⚠️ RED FLAGS - Stop and Investigate

**Immediate Action Required If:**
- 🔴 Crash rate > 5%
- 🔴 Payment success < 95%
- 🔴 API errors > 100/hour
- 🔴 User complaints about data loss
- 🔴 Firebase costs 10x normal

**Response:**
1. Check Crashlytics for error pattern
2. Check logs: `gcloud logging read`
3. Consider rollback if critical
4. Communicate with team
5. Document incident

---

## 🔗 Quick Links

| Resource | URL |
|----------|-----|
| Firebase Console | https://console.firebase.google.com |
| Stripe Dashboard | https://dashboard.stripe.com |
| Crashlytics | Firebase Console → Crashlytics |
| Cloud Scheduler | Google Cloud Console → Scheduler |
| Firestore | Firebase Console → Firestore |

---

## 📚 Documentation Tree

```
PRODUCTION_READINESS_SUMMARY.md  ← START HERE (overview)
    ↓
PRODUCTION_READINESS_ASSESSMENT.md  ← Full details (14 sections)
    ↓
PRODUCTION_LAUNCH_PLAN.md  ← Step-by-step tasks
    ↓
FUNCTIONAL_TESTING_CHECKLIST.md  ← Before launch testing
    ↓
DEPLOYMENT_SAFETY.md  ← Deployment procedures
```

---

## 💡 Pro Tips

1. **Always test in staging first** - Catch issues before production
2. **Use staged rollouts** - Release to 10% → 50% → 100% of users
3. **Monitor continuously for first 24 hours** - Most issues appear early
4. **Have rollback plan ready** - Hope for best, prepare for worst
5. **Document everything** - Future you will thank present you

---

## ⏱️ Timeline at a Glance

```
Day 1-2:  Database + Security (4 hours)
Day 3-4:  Testing + Docs (8 hours)
Day 5:    Final prep + staging (4 hours)
Day 6:    🚀 LAUNCH
Day 6-7:  Monitor closely
Week 2+:  Improvements
```

---

## 🎯 Definition of Done

**You're ready to launch when:**

✅ All 9 blockers resolved  
✅ Tests passing  
✅ Staging environment tested 48+ hours  
✅ Team trained on procedures  
✅ Monitoring configured  
✅ On-call rotation scheduled  
✅ Communication plan ready  

**Score:** [___] / 7

If all checked, you're **GO FOR LAUNCH** 🚀

---

**Last Updated:** November 20, 2024  
**Keep this handy during launch week!**

