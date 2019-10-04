// Utilidad para ejecutar comandos en el S.O.
const spawn = require("child_process").spawn;

function shell(command, args, cwd) {
  let options = { shell: "/bin/bash" };
  options.cwd = cwd ? cwd : null;

  console.log("Running", command, args.toString().replace(/,/g, " "));
  console.log("Path: ", options.cwd);
  return spawn(command, args, options).on("error", err => {
    console.error(err);
    throw err;
  });
}

export default shell;
