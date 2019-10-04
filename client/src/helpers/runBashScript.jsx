import path from "path";
import shell from "./../cli/spawn/shell";
import BaseScriptRunner from "./BaseScriptRunner.jsx";
const environment = window.require("electron").remote.process.env;

class RunBashScript extends BaseScriptRunner {
  constructor(params) {
    super(null, null);
    this.params = params;
  }

  run = () => {
    const { command, args } = this.params;

    if (this.events["updateProgress"]) this.events.updateProgress(`Running command: ${command}`);

    return new Promise((resolve, reject) => {
      try {
        const p = shell(`. ${command}`, args, `${environment.GDBROOT}/network`);

        if (this.events["stdout"]) p.stdout.on("data", this.events["stdout"]);

        if (this.events["stderr"]) p.stderr.on("data", this.events["stderr"]);

        p.on("close", code => {
          if (code === 0) resolve(code);
          else reject(code);
        });
      } catch (error) {
        console.error(error);
        reject(error);
      }
    });
  };
}

const runBashScript = params => {
  return new RunBashScript(params);
};

export default runBashScript;
