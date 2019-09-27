// TODO

// import React from "react";
// import LoadingButton from "../LoadingButton";
// import OverlayTrigger from "react-bootstrap/OverlayTrigger";
// import Tooltip from "react-bootstrap/Tooltip";
// import Modal from "react-bootstrap/Modal";
// import Spinner from "react-bootstrap/Spinner";
// import checkOrganizationContainers from "../../../helpers/checkOrganizationContainers";
// import runBashScript from "../../../helpers/runBashScript";
// import { NotificationManager } from "react-notifications";
//
// export default class Stop extends React.Component {
//   state = {
//     loading: false,
//     disabled: false,
//     composerPath: null,
//     loadingMsg: ""
//   };
//
//   handleUp = () => {
//     const { db, mode, composerPath, checkContainersStatus } = this.props;
//
//     this.setState({ loading: true });
//
//     runBashScript({ command: `start.sh`, args: [composerPath] })
//       .on("updateProgress", loadingMsg => this.setState({ loadingMsg }))
//       .on("stdout", data => console.log(`${data}`))
//       .on("stderr", data => console.error(`${data}`))
//       .run()
//       .then(() => {
//         NotificationManager.success("Command ran successfully");
//       })
//       .catch(error => {
//         console.error(error);
//         NotificationManager.error("An error occurred. Check the logs");
//       })
//       .finally(() => {
//         checkContainersStatus();
//         this.setState({ loading: false });
//       });
//   };
//
//
//
//   render() {
//     const { loading, disabled } = this.state;
//     const { organization } = this.props;
//
//     return (
//       <span>
//         <LoadingButton className="m-1" variant="danger" onClick={this.handleUp} loading={loading} disabled={disabled}>
//           <i className="fas fa-pause" /> Stop
//         </LoadingButton>
//         <Modal show={loading} size="lg" aria-labelledby="contained-modal-title-vcenter" centered backdrop="static">
//           <Modal.Body>
//             <div className="text-center">
//               <p>Running command</p>
//               <p>
//                 <small>{this.state.loadingMsg}</small>
//               </p>
//               <Spinner animation="grow" variant="primary" />
//               <Spinner animation="grow" variant="success" />
//               <Spinner animation="grow" variant="danger" />
//               <Spinner animation="grow" variant="warning" />
//               <Spinner animation="grow" variant="info" />
//             </div>
//           </Modal.Body>
//         </Modal>
//       </span>
//     );
//   }
// }
