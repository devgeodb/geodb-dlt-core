import React from "react";
import LoadingButton from "./LoadingButton";
import Modal from "react-bootstrap/Modal";
import Spinner from "react-bootstrap/Spinner";
import authorizeNewMember from "../../helpers/authorizeNewMember";
import { dataFromDatabaseEntry } from "../../helpers/extractServicesFromComposer";
import { findTypeFromJSON } from "../../helpers/getDockerServiceType";
import { NotificationManager } from "react-notifications";

class AuthorizeNewMember extends React.Component {
  state = {
    loading: false,
    loadingMsg: ""
  };

  handleAuthorizeNewMember = () => {
    this.setState({ loading: true });
    const { organization, db, mode, _event } = this.props;

    dataFromDatabaseEntry(organization)
      .then(services => {
        const cli = findTypeFromJSON(services, "cli").container_name;
        const orderer = "orderer0.operations.geodb.com:7050";
        const channel = "rewards";
        // const ordererData = findTypeFromJSON(services, "orderer");
        // const orderer = `${ordererData.container_name}:${ordererData.ports[0].split(":")[0]}`; // Build URL:port

        const params = {
          cli,
          orderer,
          channel,
          updateDeltaOutputFileName: _event.values.updateDeltaOutputFileName
        };

        return authorizeNewMember(params, db, mode)
          .on("updateProgress", loadingMsg => {
            this.setState({ loadingMsg });
          })
          .on("stdout", data => console.log(`${data}`))
          .on("stderr", data => console.error(`${data}`))
          .run();
      })
      .then(code => {
        db.events.update(
          { _id: _event._id },
          { $push: { approvedBy: organization.domain }, $set: { resolved: code === 0 } }
        );
        NotificationManager.success("Command ran successfully");
      })
      .catch(error => {
        console.error(error);
        NotificationManager.error("An error occurred. Check the logs");
      })
      .finally(() => {
        this.setState({ loading: false });
      });
  };

  render() {
    const { loading } = this.state;

    return (
      <div>
        <LoadingButton block onClick={this.handleAuthorizeNewMember} loading={loading}>
          Authorize
        </LoadingButton>
        <Modal show={loading} size="lg" aria-labelledby="contained-modal-title-vcenter" centered backdrop="static">
          <Modal.Body>
            <div className="text-center">
              <p>Authorizing member</p>
              <p>
                <small>{this.state.loadingMsg}</small>
              </p>
              <Spinner animation="grow" variant="primary" />
              <Spinner animation="grow" variant="success" />
              <Spinner animation="grow" variant="danger" />
              <Spinner animation="grow" variant="warning" />
              <Spinner animation="grow" variant="info" />
            </div>
          </Modal.Body>
        </Modal>
      </div>
    );
  }
}

export default AuthorizeNewMember;
