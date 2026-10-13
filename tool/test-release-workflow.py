"""Offline release graph contracts; no credentials, signing or GitHub mutations."""
from pathlib import Path
import unittest
import subprocess
import re
import yaml
ROOT = Path(__file__).resolve().parents[1]
class ReleaseWorkflow(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw=(ROOT/'.github/workflows/signed-release.yml').read_text()
        cls.flow=yaml.safe_load(cls.raw)
        cls.jobs=cls.flow['jobs']
        cls.inputs=cls.flow.get('on',cls.flow.get(True))['workflow_dispatch']['inputs']
    def test_safe_default_and_explicit_publication_choice(self):
        mode=self.inputs['delivery_mode']
        self.assertEqual(mode['default'],'rehearsal')
        self.assertEqual(mode['options'],['rehearsal','publish'])
    def test_sign_cannot_publish_or_write_repository(self):
        self.assertEqual(self.jobs['sign']['permissions']['contents'],'read')
        self.assertNotIn('gh release create',str(self.jobs['sign']))
    def test_publish_needs_verified_build_and_sign(self):
        job=self.jobs['publish']
        self.assertEqual(job['needs'],['build','sign'])
        condition=job['if']
        for gate in ["needs.build.result == 'success'","needs.sign.result == 'success'","inputs.delivery_mode == 'publish'","github.ref_name == github.event.repository.default_branch"]:
            self.assertIn(gate,condition)
        self.assertEqual(job['permissions']['contents'],'write')
    def test_default_tip_gates_survive_build_and_publication(self):
        self.assertIn('test "$CANDIDATE_REF" = "$default_tip"',str(self.jobs['build']))
        self.assertIn('test "$CANDIDATE_SHA" = "$default_tip"',str(self.jobs['publish']))
    def test_sign_checks_tip_before_secret_step(self):
        steps=self.jobs['sign']['steps']
        check=next(i for i,s in enumerate(steps) if s.get('name')=='Recheck immutable approved tip before signing secrets enter')
        secret=next(i for i,s in enumerate(steps) if 'MUSIFY_SIGNING_KEY_BASE64' in s.get('env',{}))
        self.assertLess(check,secret)
        self.assertIn('test "$CANDIDATE_SHA" = "$default_tip"',steps[check]['run'])
    def test_rehearsal_is_only_sole_candidate_and_pinned_dispatch(self):
        for name in ['build','sign']:
            self.assertIn("github.ref_name == 'agent/local-stable-consolidation'",self.jobs[name]['if'])
        build="\n".join(s.get('run','') for s in self.jobs['build']['steps'])
        sign="\n".join(s.get('run','') for s in self.jobs['sign']['steps'])
        self.assertIn('test "$CANDIDATE_REF" = "$GITHUB_SHA"',build)
        self.assertIn('test "$CANDIDATE_SHA" = "$GITHUB_SHA"',sign)
        self.assertIn('test "$CANDIDATE_SHA" = "$candidate_tip"',sign)
        self.assertIn("inputs.delivery_mode == 'publish'",self.jobs['publish']['if'])
    def test_all_shell_blocks_parse_without_execution(self):
        bash=Path('C:/Program Files/Git/bin/bash.exe')
        if not bash.exists():self.skipTest('Local bash syntax checker unavailable')
        for job in self.jobs.values():
            for step in job['steps']:
                if 'run' in step:
                    script=re.sub(r'\$\{\{.*?\}\}','STATIC_CONTEXT',step['run'])
                    result=subprocess.run([str(bash),'--noprofile','--norc','-n'],input=script,text=True,capture_output=True)
                    self.assertEqual(result.returncode,0,result.stderr)
    def test_signature_identity_and_monotonic_version_gates_survive(self):
        for token in ['58c5316466da7a426c4411beb33b3b594ef58875bcfa31e092a5afce8cf9999e','--v2-signing-enabled true','--v3-signing-enabled true','com.topcat432.musifypersonalized.preview','build_number <= published_build_number','application-debuggable']:
            self.assertIn(token,self.raw)
    def test_publication_downloads_and_checks_same_artifact(self):
        artifact=[s for s in self.jobs['sign']['steps'] if s.get('uses','').startswith('actions/upload-artifact')][0]['with']['name']
        download=self.jobs['publish']['steps'][0]['with']['name']
        self.assertEqual(artifact,download)
        self.assertIn('sha256sum -c musify-personalized-production.apk.sha256',str(self.jobs['publish']))
        self.assertIn('${{ needs.sign.outputs.tag }}',str(self.jobs['publish']))
    def test_secrets_remain_only_in_isolated_sign_job(self):
        for name,job in self.jobs.items():
            if name!='sign':self.assertNotIn('secrets.MUSIFY_SIGNING_',str(job))
        self.assertIn("trap 'rm -f", "\n".join(step.get("run", "") for step in self.jobs["sign"]["steps"]))
    def test_rehearsal_does_not_create_draft_or_live_release(self):
        self.assertEqual(self.raw.count('gh release create'),1)
        self.assertNotIn('gh release edit',self.raw)
        self.assertIn('rehearsal|publish',str(self.jobs['build']))
if __name__=='__main__':unittest.main()
